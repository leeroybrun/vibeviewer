import Foundation
import Observation
import AIUsageTrackerAPI
import AIUsageTrackerModel
import AIUsageTrackerStorage
import AIUsageTrackerCore

/// Background refresh service interface.
public protocol DashboardRefreshService: Sendable {
    @MainActor var isRefreshing: Bool { get }
    @MainActor var isPaused: Bool { get }
    @MainActor func start() async
    @MainActor func stop()
    @MainActor func pause()
    @MainActor func resume() async
    @MainActor func refreshNow() async
}

/// No-op implementation used for environment defaults and previews.
public struct NoopDashboardRefreshService: DashboardRefreshService {
    public init() {}
    public var isRefreshing: Bool { false }
    public var isPaused: Bool { false }
    @MainActor public func start() async {}
    @MainActor public func stop() {}
    @MainActor public func pause() {}
    @MainActor public func resume() async {}
    @MainActor public func refreshNow() async {}
}

@MainActor
@Observable
public final class DefaultDashboardRefreshService: DashboardRefreshService {
    private let api: CursorService
    private let storage: any CursorStorageService
    private let settings: AppSettings
    private let session: AppSession
    private let credentialResolver: ProviderCredentialResolving
    private let usageCache: IncrementalUsageCache
    private let analyticsEngine = UsageAnalyticsEngine()
    private let logger = DiagnosticsLogger.shared
    private let exchangeRateService = ExchangeRateService()
    private var loopTask: Task<Void, Never>?
    public private(set) var isRefreshing: Bool = false
    public private(set) var isPaused: Bool = false

    public init(
        api: CursorService,
        storage: any CursorStorageService,
        settings: AppSettings,
        session: AppSession,
        credentialResolver: ProviderCredentialResolving,
        usageCache: IncrementalUsageCache = .shared
    ) {
        self.api = api
        self.storage = storage
        self.settings = settings
        self.session = session
        self.credentialResolver = credentialResolver
        self.usageCache = usageCache
    }

    public func start() async {
        await self.bootstrapIfNeeded()
        await self.refreshNow()

        self.loopTask?.cancel()
        self.loopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                // When paused, wait before checking again.
                if self.isPaused {
                    try? await Task.sleep(for: .seconds(30)) // Poll every 30 seconds while paused.
                    continue
                }
                await self.refreshNow()
                // Refresh every five minutes.
                try? await Task.sleep(for: .seconds(5 * 60))
            }
        }
    }

    public func stop() {
        self.loopTask?.cancel()
        self.loopTask = nil
    }

    public func pause() {
        self.isPaused = true
    }

    public func resume() async {
        self.isPaused = false
        // Kick off an immediate refresh.
        await self.refreshNow()
    }

    public func refreshNow() async {
        if self.isRefreshing || self.isPaused { return }
        self.isRefreshing = true
        defer { self.isRefreshing = false }
        if self.settings.advanced.enableDiagnosticsLogging {
            Task { await self.logger.log("Refresh started") }
        }
        await self.bootstrapIfNeeded()
        guard let creds = self.session.credentials else { return }

        do {
            // Compute time ranges for analytics and usage.
            let (analyticsStartMs, analyticsEndMs) = self.analyticsDateRangeMs()

            // Issue the independent API requests concurrently via async let.
            async let usageSummary = try await self.api.fetchUsageSummary(
                cookieHeader: creds.cookieHeader
            )
            async let cursorEventsTask = self.refreshCursorUsage(
                credentials: creds,
                startDateMs: analyticsStartMs,
                endDateMs: analyticsEndMs
            )
            async let analytics = try await self.api.fetchUserAnalytics(
                userId: creds.userId,
                startDateMs: analyticsStartMs,
                endDateMs: analyticsEndMs,
                cookieHeader: creds.cookieHeader
            )
            async let providerTotalsTask = self.fetchExternalProviderTotals()

            // Await the usage summary to determine membership context.
            let usageSummaryValue = try await usageSummary
            
            // totalRequestsAllModels will be derived from usage events rather than API totals.
            let totalAll = 0 // Placeholder; usage events provide the real total later.

            let current = self.session.snapshot

            // Compute free usage for team plans when applicable.
            func computeFreeCents() async -> Int {
                if usageSummaryValue.membershipType == .enterprise && creds.isEnterpriseUser == false {
                    return (try? await self.api.fetchTeamFreeUsageCents(
                        teamId: creds.teamId,
                        userId: creds.userId,
                        cookieHeader: creds.cookieHeader
                    )) ?? 0
                }
                return 0
            }
            let freeCents = await computeFreeCents()

            // Update the overview immediately using cached events so the UI stays responsive.
            let overview = DashboardSnapshot(
                email: creds.email,
                totalRequestsAllModels: totalAll,
                spendingCents: usageSummaryValue.individualUsage.plan.used,
                hardLimitDollars: usageSummaryValue.individualUsage.plan.limit / 100,
                usageEvents: current?.usageEvents ?? [],
                requestToday: current?.requestToday ?? 0,
                requestYestoday: current?.requestYestoday ?? 0,
                usageSummary: usageSummaryValue,
                freeUsageCents: freeCents,
                userAnalytics: current?.userAnalytics,
                providerTotals: current?.providerTotals ?? []
            )
            self.session.snapshot = overview
            try? await self.storage.saveDashboardSnapshot(overview)

            // Await the concurrent history and analytics tasks and merge the results.
            let events = try await cursorEventsTask
            let analyticsValue: UserAnalytics?
            do {
                analyticsValue = try await analytics
            } catch {
                analyticsValue = nil
            }
            let (reqToday, reqYesterday) = self.splitTodayAndYesterdayCounts(from: events)
            let providerTotals = await providerTotalsTask
            let cursorSpend = usageSummaryValue.individualUsage.plan.used + (usageSummaryValue.individualUsage.onDemand?.used ?? 0)
            let cursorRequests = events.reduce(0) { $0 + $1.requestCostCount }
            let cursorTotal = ProviderUsageTotal(
                provider: .cursor,
                spendCents: cursorSpend,
                requestCount: cursorRequests,
                currencyCode: "USD"
            )
            let totalsWithCursor = [cursorTotal] + providerTotals
            let analyticsResult = self.analyticsEngine.evaluate(
                events: events,
                providerTotals: totalsWithCursor,
                settings: self.settings,
                existingSnapshot: current
            )
            let localizedDisplay = await self.localizedSpendDisplay(
                totals: totalsWithCursor,
                personalization: analyticsResult.personalization
            )
            let merged = DashboardSnapshot(
                email: overview.email,
                totalRequestsAllModels: overview.totalRequestsAllModels,
                spendingCents: overview.spendingCents,
                hardLimitDollars: overview.hardLimitDollars,
                usageEvents: events,
                requestToday: reqToday,
                requestYestoday: reqYesterday,
                usageSummary: usageSummaryValue,
                freeUsageCents: overview.freeUsageCents,
                userAnalytics: analyticsValue,
                providerTotals: totalsWithCursor,
                aggregations: analyticsResult.aggregations,
                forecastWarnings: analyticsResult.warnings,
                personalization: analyticsResult.personalization,
                liveMetrics: analyticsResult.liveMetrics,
                developerExport: analyticsResult.developerExport,
                localizedSpendDisplay: localizedDisplay,
                costComparisons: analyticsResult.costComparisons
            )
            self.session.snapshot = merged
            try? await self.storage.saveDashboardSnapshot(merged)
            if self.settings.advanced.enableDiagnosticsLogging {
                Task { await self.logger.log("Refresh succeeded with \(events.count) events") }
            }
        } catch {
            // Swallow the error but log diagnostics if enabled.
            if self.settings.advanced.enableDiagnosticsLogging {
                Task { await self.logger.log("Refresh failed: \(error.localizedDescription)") }
            }
        }
    }

    private func bootstrapIfNeeded() async {
        if self.session.snapshot == nil, let cached = await self.storage.loadDashboardSnapshot() {
            self.session.snapshot = cached
        }
        if self.session.credentials == nil {
            self.session.credentials = await self.storage.loadCredentials()
        }
    }

    private func yesterdayToNowRangeMs() -> (String, String) {
        let (start, end) = AIUsageTrackerCore.DateUtils.yesterdayToNowRange()
        return (AIUsageTrackerCore.DateUtils.millisecondsString(from: start), AIUsageTrackerCore.DateUtils.millisecondsString(from: end))
    }

    private func analyticsDateRangeMs() -> (String, String) {
        let days = self.settings.analyticsDataDays
        let (start, end) = AIUsageTrackerCore.DateUtils.daysAgoToNowRange(days: days)
        return (AIUsageTrackerCore.DateUtils.millisecondsString(from: start), AIUsageTrackerCore.DateUtils.millisecondsString(from: end))
    }

    private func providerDateRange() -> DateInterval {
        let days = max(self.settings.analyticsDataDays, 1)
        let (start, end) = AIUsageTrackerCore.DateUtils.daysAgoToNowRange(days: days)
        return DateInterval(start: start, end: end)
    }

    private func fetchExternalProviderTotals() async -> [ProviderUsageTotal] {
        let aggregator = MultiProviderUsageAggregator(
            configuration: .init(
                settings: self.settings.providerSettings,
                credentialResolver: self.credentialResolver
            )
        )
        let range = self.providerDateRange()
        return await aggregator.fetchTotals(dateRange: range)
    }

    private func splitTodayAndYesterdayCounts(from events: [UsageEvent]) -> (Int, Int) {
        let calendar = Calendar.current
        var today = 0
        var yesterday = 0
        for e in events {
            guard let date = AIUsageTrackerCore.DateUtils.date(fromMillisecondsString: e.occurredAtMs) else { continue }
            if calendar.isDateInToday(date) {
                today += e.requestCostCount
            } else if calendar.isDateInYesterday(date) {
                yesterday += e.requestCostCount
            }
        }
        return (today, yesterday)
    }

    private func refreshCursorUsage(credentials: Credentials, startDateMs: String, endDateMs: String) async throws -> [UsageEvent] {
        let cached = await self.usageCache.loadEvents()
        if cached.isEmpty {
            let firstPage = try await self.api.fetchFilteredUsageEvents(
                startDateMs: startDateMs,
                endDateMs: endDateMs,
                userId: credentials.userId,
                page: 1,
                cookieHeader: credentials.cookieHeader
            )
            try await self.usageCache.overwrite(events: firstPage.events, watermark: firstPage.events.first?.occurredAtMs)
            if self.settings.advanced.enableDiagnosticsLogging {
                Task { await self.logger.log("Primed usage cache with \(firstPage.events.count) events") }
            }
            return firstPage.events
        }

        let newEvents = try await self.fetchNewEvents(credentials: credentials, startDateMs: startDateMs, endDateMs: endDateMs)
        let merged = try await self.usageCache.append(newEvents: newEvents, retentionDays: self.settings.advanced.logRetentionDays)
        if self.settings.advanced.enableDiagnosticsLogging {
            Task { await self.logger.log("Appended \(newEvents.count) new events (total \(merged.count))") }
        }
        return merged
    }

    private func fetchNewEvents(credentials: Credentials, startDateMs: String, endDateMs: String) async throws -> [UsageEvent] {
        let watermark = await self.usageCache.currentWatermark()
        var page = 1
        var collected: [UsageEvent] = []
        let maxPages = 5
        while page <= maxPages {
            let pageResult = try await self.api.fetchFilteredUsageEvents(
                startDateMs: startDateMs,
                endDateMs: endDateMs,
                userId: credentials.userId,
                page: page,
                cookieHeader: credentials.cookieHeader
            )
            guard !pageResult.events.isEmpty else { break }
            for event in pageResult.events {
                if let watermark, event.occurredAtMs <= watermark {
                    return collected
                }
                collected.append(event)
            }
            if pageResult.events.count < 50 { break }
            page += 1
        }
        return collected
    }

    private func localizedSpendDisplay(totals: [ProviderUsageTotal], personalization: PersonalizationProfile) async -> String? {
        guard personalization.currencyCode.uppercased() != "USD" else { return nil }
        let totalCents = totals.reduce(0) { partialResult, total in
            partialResult + total.spendCents
        }
        guard let rate = await exchangeRateService.rate(for: personalization.currencyCode) else { return nil }
        let converted = (Double(totalCents) / 100.0) * rate
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = personalization.currencyCode
        return formatter.string(from: NSNumber(value: converted))
    }
}


