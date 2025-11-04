import Foundation
import AIUsageTrackerModel

public struct UsageAnalyticsResult: Sendable {
    public let aggregations: [UsageAggregationMetric]
    public let warnings: [ForecastWarning]
    public let liveMetrics: LiveUsageMetrics?
    public let personalization: PersonalizationProfile
    public let developerExport: DeveloperExport
    public let costComparisons: [ProviderCostComparison]

    public init(
        aggregations: [UsageAggregationMetric],
        warnings: [ForecastWarning],
        liveMetrics: LiveUsageMetrics?,
        personalization: PersonalizationProfile,
        developerExport: DeveloperExport,
        costComparisons: [ProviderCostComparison]
    ) {
        self.aggregations = aggregations
        self.warnings = warnings
        self.liveMetrics = liveMetrics
        self.personalization = personalization
        self.developerExport = developerExport
        self.costComparisons = costComparisons
    }
}

public struct UsageAnalyticsEngine: Sendable {
    public init() {}

    public func evaluate(
        events: [UsageEvent],
        providerTotals: [ProviderUsageTotal],
        settings: AppSettings,
        existingSnapshot: DashboardSnapshot?
    ) -> UsageAnalyticsResult {
        let personalization = buildPersonalization(settings: settings, snapshot: existingSnapshot)
        let aggregations = buildAggregations(events: events, providerTotals: providerTotals, personalization: personalization)
        let warnings = buildForecasts(events: events, personalization: personalization, settings: settings)
        let liveMetrics = buildLiveMetrics(events: events)
        let export = buildDeveloperExport(
            aggregations: aggregations,
            liveMetrics: liveMetrics,
            warnings: warnings,
            settings: settings,
            personalization: personalization
        )
        let costComparisons = buildCostComparisons(
            events: events,
            settings: settings
        )
        return UsageAnalyticsResult(
            aggregations: aggregations,
            warnings: warnings,
            liveMetrics: liveMetrics,
            personalization: personalization,
            developerExport: export,
            costComparisons: costComparisons
        )
    }

    private func buildPersonalization(settings: AppSettings, snapshot: DashboardSnapshot?) -> PersonalizationProfile {
        if settings.advanced.autoDetectPreferences {
            let locale = Locale.autoupdatingCurrent
            let tz = TimeZone.autoupdatingCurrent
            let currency = locale.currency?.identifier ?? "USD"
            let inferredPlan = snapshot?.usageSummary?.individualUsage.plan.limit > 0 ? "Paid" : nil
            return PersonalizationProfile(
                localeIdentifier: locale.identifier,
                timezoneIdentifier: tz.identifier,
                currencyCode: currency,
                appearance: settings.appearance,
                inferredPlan: inferredPlan
            )
        }
        return PersonalizationProfile(
            localeIdentifier: settings.providerSettings.openAIOrganization ?? Locale.current.identifier,
            timezoneIdentifier: TimeZone.current.identifier,
            currencyCode: "USD",
            appearance: settings.appearance,
            inferredPlan: nil
        )
    }

    private func buildAggregations(
        events: [UsageEvent],
        providerTotals: [ProviderUsageTotal],
        personalization: PersonalizationProfile
    ) -> [UsageAggregationMetric] {
        guard !events.isEmpty else {
            let providerRows = providerTotals.map { total in
                UsageAggregationRow(
                    preset: .providerTotals,
                    startDate: Date(),
                    endDate: Date(),
                    requestCount: total.requestCount,
                    spendCents: total.spendCents,
                    providerIdentifier: total.provider.rawValue
                )
            }
            return providerRows.isEmpty ? [] : [UsageAggregationMetric(preset: .providerTotals, rows: providerRows)]
        }

        var metrics: [UsageAggregationMetric] = []
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(identifier: personalization.timezoneIdentifier) ?? .current
        var cal = calendar
        cal.timeZone = tz

        let sorted = events.sorted { lhs, rhs in
            guard let lDate = DateUtils.date(fromMillisecondsString: lhs.occurredAtMs),
                  let rDate = DateUtils.date(fromMillisecondsString: rhs.occurredAtMs) else { return false }
            return lDate > rDate
        }

        func aggregate(by component: Calendar.Component, spanHours: Int? = nil) -> UsageAggregationMetric {
            var buckets: [Date: (Int, Int)] = [:]
            for event in sorted {
                guard let date = DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { continue }
                let key: Date
                if let spanHours {
                    let comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
                    let adjustedHour = (comps.hour ?? 0) / spanHours * spanHours
                    key = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day, hour: adjustedHour)) ?? date
                } else {
                    key = cal.dateInterval(of: component, for: date)?.start ?? date
                }
                var entry = buckets[key] ?? (0, 0)
                entry.0 += event.requestCostCount
                entry.1 += event.usageCostCents
                buckets[key] = entry
            }
            let rows = buckets.keys.sorted(by: { $0 < $1 }).map { start -> UsageAggregationRow in
                let end: Date
                if let spanHours {
                    end = cal.date(byAdding: .hour, value: spanHours, to: start) ?? start
                } else if let interval = cal.dateInterval(of: component, for: start) {
                    end = interval.end
                } else {
                    end = start
                }
                let values = buckets[start] ?? (0, 0)
                return UsageAggregationRow(
                    preset: componentPreset(component: component, spanHours: spanHours),
                    startDate: start,
                    endDate: end,
                    requestCount: values.0,
                    spendCents: values.1
                )
            }
            return UsageAggregationMetric(
                preset: componentPreset(component: component, spanHours: spanHours),
                rows: rows
            )
        }

        metrics.append(aggregate(by: .hour, spanHours: 5))
        metrics.append(aggregate(by: .day))
        metrics.append(aggregate(by: .weekOfYear))
        metrics.append(aggregate(by: .month))

        let sessionRows = buildSessionRows(events: sorted, calendar: cal)
        metrics.append(UsageAggregationMetric(preset: .sessions, rows: sessionRows))

        if !providerTotals.isEmpty {
            let providerRows = providerTotals.map { total in
                UsageAggregationRow(
                    preset: .providerTotals,
                    startDate: Date(),
                    endDate: Date(),
                    requestCount: total.requestCount,
                    spendCents: total.spendCents,
                    providerIdentifier: total.provider.rawValue
                )
            }
            metrics.append(UsageAggregationMetric(preset: .providerTotals, rows: providerRows))
        }

        return metrics
    }

    private func componentPreset(component: Calendar.Component, spanHours: Int?) -> UsageAggregationPreset {
        if let spanHours, spanHours == 5 { return .fiveHourBlocks }
        switch component {
        case .day: return .daily
        case .weekOfYear: return .weekly
        case .month: return .monthly
        default: return .daily
        }
    }

    private func buildSessionRows(events: [UsageEvent], calendar: Calendar) -> [UsageAggregationRow] {
        guard !events.isEmpty else { return [] }
        var rows: [UsageAggregationRow] = []
        var currentStart: Date?
        var currentEnd: Date?
        var requestCount = 0
        var spend = 0
        let sessionGap: TimeInterval = 30 * 60

        for event in events.sorted(by: { $0.occurredAtMs < $1.occurredAtMs }) {
            guard let date = DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { continue }
            if let end = currentEnd, date.timeIntervalSince(end) > sessionGap {
                if let start = currentStart, let endDate = currentEnd {
                    rows.append(
                        UsageAggregationRow(
                            preset: .sessions,
                            startDate: start,
                            endDate: endDate,
                            requestCount: requestCount,
                            spendCents: spend
                        )
                    )
                }
                currentStart = date
                currentEnd = date
                requestCount = event.requestCostCount
                spend = event.usageCostCents
            } else {
                currentStart = currentStart ?? date
                currentEnd = date
                requestCount += event.requestCostCount
                spend += event.usageCostCents
            }
        }

        if let start = currentStart, let end = currentEnd {
            rows.append(
                UsageAggregationRow(
                    preset: .sessions,
                    startDate: start,
                    endDate: end,
                    requestCount: requestCount,
                    spendCents: spend
                )
            )
        }
        return rows
    }

    private func buildForecasts(
        events: [UsageEvent],
        personalization: PersonalizationProfile,
        settings: AppSettings
    ) -> [ForecastWarning] {
        guard !events.isEmpty else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        var cal = calendar
        cal.timeZone = TimeZone(identifier: personalization.timezoneIdentifier) ?? .current
        var dailySpend: [Date: Int] = [:]
        for event in events {
            guard let date = DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { continue }
            let start = cal.startOfDay(for: date)
            dailySpend[start, default: 0] += event.usageCostCents
        }
        let values = dailySpend.values.sorted()
        guard !values.isEmpty else { return [] }
        let percentileIndex = Int(Double(values.count - 1) * 0.9)
        let p90 = values[min(max(percentileIndex, 0), values.count - 1)]
        let burnRate = Double(p90) / 24.0
        let projected = Int(burnRate * 24.0 * 30.0)
        let threshold = Int(Double(settings.overview.refreshInterval) * settings.advanced.notificationThresholdPercent * 100)
        let severity: ForecastSeverity
        if projected >= threshold * 2 {
            severity = .critical
        } else if projected >= threshold {
            severity = .warning
        } else {
            severity = .info
        }
        let message = "Projected monthly spend \((Double(projected) / 100.0).formatted(.currency(code: personalization.currencyCode)))"
        return [
            ForecastWarning(
                preset: .monthly,
                projectedAt: Date(),
                message: message,
                severity: severity,
                projectedValueCents: projected,
                thresholdCents: threshold
            )
        ]
    }

    private func buildLiveMetrics(events: [UsageEvent]) -> LiveUsageMetrics? {
        guard !events.isEmpty else { return nil }
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let recent = events.compactMap { event -> (Date, UsageEvent)? in
            guard let date = DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { return nil }
            return (date, event)
        }.filter { $0.0 >= hourAgo }
        guard !recent.isEmpty else {
            return LiveUsageMetrics(lastUpdated: now, burnRateCentsPerHour: 0, activeEvents: [], sparklinePoints: [])
        }
        let burn = recent.reduce(0) { $0 + $1.1.usageCostCents }
        let sorted = recent.sorted(by: { $0.0 < $1.0 })
        let points = sorted.map { Double($0.1.usageCostCents) / 100.0 }
        return LiveUsageMetrics(
            lastUpdated: now,
            burnRateCentsPerHour: Double(burn),
            activeEvents: sorted.map { $0.1 },
            sparklinePoints: points
        )
    }

    private func buildDeveloperExport(
        aggregations: [UsageAggregationMetric],
        liveMetrics: LiveUsageMetrics?,
        warnings: [ForecastWarning],
        settings: AppSettings,
        personalization: PersonalizationProfile
    ) -> DeveloperExport {
        let latestSpend = aggregations.first { $0.preset == .daily }?.rows.last?.spendCents ?? 0
        let warningText = warnings.first?.message ?? "Stable"
        let statusLine = "Spend: \((Double(latestSpend) / 100.0).formatted(.currency(code: personalization.currencyCode))) | Status: \(warningText)"
        let exportPath = (settings.advanced.statusExportPath as NSString).expandingTildeInPath
        return DeveloperExport(statusLine: statusLine, exportPath: exportPath, lastWritten: Date())
    }

    private func buildCostComparisons(
        events: [UsageEvent],
        settings: AppSettings
    ) -> [ProviderCostComparison] {
        guard !events.isEmpty else { return [] }

        var firstEventDate: Date = .distantFuture
        var lastEventDate: Date = .distantPast
        var paygByProvider: [UsageProviderKind: Int] = [:]

        for event in events {
            guard let occurred = DateUtils.date(fromMillisecondsString: event.occurredAtMs) else { continue }
            if occurred < firstEventDate { firstEventDate = occurred }
            if occurred > lastEventDate { lastEventDate = occurred }
            guard let provider = providerKind(for: event.brand) else { continue }
            let estimated = estimatedCost(for: event, settings: settings)
            guard estimated > 0 else { continue }
            paygByProvider[provider, default: 0] += estimated
        }

        guard firstEventDate < lastEventDate else { return [] }
        let seconds = lastEventDate.timeIntervalSince(firstEventDate)
        let daysCovered = max(1, Int(ceil(seconds / 86_400.0)))
        let subscriptionTotal = proRatedCursorSubscription(settings: settings, daysCovered: daysCovered)
        let totalPayg = paygByProvider.values.reduce(0, +)
        guard totalPayg > 0 else { return [] }

        return UsageProviderKind.allCases
            .filter { $0 != .cursor }
            .compactMap { provider in
                guard let payg = paygByProvider[provider], payg > 0 else { return nil }
                let allocated = max(0, subscriptionTotal * payg / totalPayg) + proRatedAddon(for: provider, settings: settings, daysCovered: daysCovered)
                let difference = allocated - payg
                return ProviderCostComparison(
                    provider: provider,
                    estimatedPayAsYouGoCents: payg,
                    subscriptionValueCents: allocated,
                    differenceCents: difference,
                    periodStart: firstEventDate,
                    periodEnd: lastEventDate
                )
            }
            .sorted { lhs, rhs in
                lhs.estimatedPayAsYouGoCents > rhs.estimatedPayAsYouGoCents
            }
    }

    private func proRatedCursorSubscription(settings: AppSettings, daysCovered: Int) -> Int {
        guard settings.pricing.cursorPlanMonthlyCents > 0 else { return 0 }
        return settings.pricing.cursorPlanMonthlyCents * daysCovered / 30
    }

    private func proRatedAddon(for provider: UsageProviderKind, settings: AppSettings, daysCovered: Int) -> Int {
        let monthly: Int
        switch provider {
        case .openAI:
            monthly = settings.pricing.openAIPlanMonthlyCents
        case .anthropic:
            monthly = settings.pricing.anthropicPlanMonthlyCents
        case .googleGemini:
            monthly = settings.pricing.googlePlanMonthlyCents
        case .cursor:
            monthly = 0
        }
        guard monthly > 0 else { return 0 }
        return monthly * daysCovered / 30
    }

    private func providerKind(for brand: AIModelBrands) -> UsageProviderKind? {
        switch brand {
        case .gpt:
            return .openAI
        case .claude:
            return .anthropic
        case .gemini:
            return .googleGemini
        default:
            return nil
        }
    }

    private func estimatedCost(for event: UsageEvent, settings: AppSettings) -> Int {
        if let usage = event.tokenUsage {
            if let override = settings.pricing.perModelOverrides[event.modelName] {
                return computeCost(from: usage, pricing: override)
            }
            if let pricing = defaultPricing(for: event.modelName) {
                return computeCost(from: usage, pricing: pricing)
            }
            if usage.totalCents > 0 {
                return Int(usage.totalCents.rounded())
            }
        }
        if event.usageCostCents > 0 {
            return event.usageCostCents
        }
        if event.cursorTokenFee > 0 {
            return Int(event.cursorTokenFee.rounded())
        }
        return 0
    }

    private func computeCost(from usage: TokenUsage, pricing: ModelPricing) -> Int {
        let inputTokens = Double(usage.inputTokens ?? 0)
        let outputTokens = Double(usage.outputTokens ?? 0)
        let cacheWrite = Double(usage.cacheWriteTokens ?? 0)
        let cacheRead = Double(usage.cacheReadTokens ?? 0)

        let inputCost = inputTokens / 1_000.0 * pricing.inputCostPerThousandTokensCents
        let outputCost = outputTokens / 1_000.0 * pricing.outputCostPerThousandTokensCents
        let writeCost = cacheWrite / 1_000.0 * (pricing.cacheWriteCostPerThousandTokensCents ?? pricing.inputCostPerThousandTokensCents)
        let readCost = cacheRead / 1_000.0 * (pricing.cacheReadCostPerThousandTokensCents ?? pricing.outputCostPerThousandTokensCents)
        let total = inputCost + outputCost + writeCost + readCost
        return Int(total.rounded())
    }

    private func defaultPricing(for modelName: String) -> ModelPricing? {
        let catalog: [String: ModelPricing] = [
            "gpt-4.1": .init(inputCostPerThousandTokensCents: 150.0, outputCostPerThousandTokensCents: 600.0),
            "gpt-4o": .init(inputCostPerThousandTokensCents: 50.0, outputCostPerThousandTokensCents: 150.0),
            "gpt-4o-mini": .init(inputCostPerThousandTokensCents: 5.0, outputCostPerThousandTokensCents: 15.0),
            "gpt-4-turbo": .init(inputCostPerThousandTokensCents: 100.0, outputCostPerThousandTokensCents: 300.0),
            "gpt-3.5-turbo": .init(inputCostPerThousandTokensCents: 1.5, outputCostPerThousandTokensCents: 2.0),
            "claude-3-opus": .init(inputCostPerThousandTokensCents: 150.0, outputCostPerThousandTokensCents: 750.0, cacheWriteCostPerThousandTokensCents: 112.5, cacheReadCostPerThousandTokensCents: 37.5),
            "claude-3.5-sonnet": .init(inputCostPerThousandTokensCents: 30.0, outputCostPerThousandTokensCents: 75.0, cacheWriteCostPerThousandTokensCents: 22.5, cacheReadCostPerThousandTokensCents: 7.5),
            "claude-3.5-haiku": .init(inputCostPerThousandTokensCents: 3.0, outputCostPerThousandTokensCents: 15.0, cacheWriteCostPerThousandTokensCents: 2.25, cacheReadCostPerThousandTokensCents: 0.75),
            "claude-3-haiku": .init(inputCostPerThousandTokensCents: 1.25, outputCostPerThousandTokensCents: 5.0, cacheWriteCostPerThousandTokensCents: 0.94, cacheReadCostPerThousandTokensCents: 0.31),
            "claude-3-sonnet": .init(inputCostPerThousandTokensCents: 3.0, outputCostPerThousandTokensCents: 15.0),
            "gemini-1.5-pro": .init(inputCostPerThousandTokensCents: 35.0, outputCostPerThousandTokensCents: 105.0),
            "gemini-1.5-flash": .init(inputCostPerThousandTokensCents: 0.35, outputCostPerThousandTokensCents: 1.05),
            "gemini-1.0-pro": .init(inputCostPerThousandTokensCents: 5.0, outputCostPerThousandTokensCents: 15.0)
        ]

        if let exact = catalog[modelName] {
            return exact
        }

        if modelName.hasPrefix("gpt-4o") {
            return catalog["gpt-4o"]
        }
        if modelName.hasPrefix("gpt-4") {
            return catalog["gpt-4-turbo"]
        }
        if modelName.hasPrefix("gpt-3.5") {
            return catalog["gpt-3.5-turbo"]
        }
        if modelName.hasPrefix("claude-3.5-sonnet") {
            return catalog["claude-3.5-sonnet"]
        }
        if modelName.hasPrefix("claude-3.5-haiku") {
            return catalog["claude-3.5-haiku"]
        }
        if modelName.hasPrefix("claude-3") {
            return catalog["claude-3-sonnet"]
        }
        if modelName.hasPrefix("gemini-1.5-pro") {
            return catalog["gemini-1.5-pro"]
        }
        if modelName.hasPrefix("gemini-1.5-flash") {
            return catalog["gemini-1.5-flash"]
        }
        if modelName.hasPrefix("gemini") {
            return catalog["gemini-1.0-pro"]
        }
        return nil
    }
}
