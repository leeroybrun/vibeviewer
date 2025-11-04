import Foundation
import Moya
import AIUsageTrackerModel

public enum CursorServiceError: Error {
    case sessionExpired
}

protocol CursorNetworkClient {
    func decodableRequest<T: DecodableTargetType>(
        _ target: T,
        decodingStrategy: JSONDecoder.KeyDecodingStrategy
    ) async throws -> T
        .ResultType
}

struct DefaultCursorNetworkClient: CursorNetworkClient {
    init() {}

    func decodableRequest<T>(_ target: T, decodingStrategy: JSONDecoder.KeyDecodingStrategy) async throws -> T
        .ResultType where T: DecodableTargetType
    {
        try await HttpClient.decodableRequest(target, decodingStrategy: decodingStrategy)
    }
}

public protocol CursorService {
    func fetchMe(cookieHeader: String) async throws -> Credentials
    func fetchUsageSummary(cookieHeader: String) async throws -> AIUsageTrackerModel.UsageSummary
    /// Team-plan only: returns the current member's free usage in cents.
    /// Calculation: `includedSpendCents - hardLimitOverrideDollars * 100`, floored at zero.
    func fetchTeamFreeUsageCents(teamId: Int, userId: Int, cookieHeader: String) async throws -> Int
    func fetchFilteredUsageEvents(
        startDateMs: String,
        endDateMs: String,
        userId: Int,
        page: Int,
        cookieHeader: String
    ) async throws -> AIUsageTrackerModel.FilteredUsageHistory
    func fetchUserAnalytics(
        userId: Int,
        startDateMs: String,
        endDateMs: String,
        cookieHeader: String
    ) async throws -> AIUsageTrackerModel.UserAnalytics
}

public struct DefaultCursorService: CursorService {
    private let network: CursorNetworkClient
    private let decoding: JSONDecoder.KeyDecodingStrategy

    // Public initializer that does not expose internal protocol types
    public init(decoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) {
        self.network = DefaultCursorNetworkClient()
        self.decoding = decoding
    }

    // Internal injectable initializer for tests
    init(network: any CursorNetworkClient, decoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) {
        self.network = network
        self.decoding = decoding
    }

    private func performRequest<T: DecodableTargetType>(_ target: T) async throws -> T.ResultType {
        do {
            return try await self.network.decodableRequest(target, decodingStrategy: self.decoding)
        } catch {
            if let moyaError = error as? MoyaError,
               case let .statusCode(response) = moyaError,
               [401, 403].contains(response.statusCode)
            {
                throw CursorServiceError.sessionExpired
            }
            throw error
        }
    }

    public func fetchMe(cookieHeader: String) async throws -> Credentials {
        let dto: CursorMeResponse = try await self.performRequest(CursorGetMeAPI(cookieHeader: cookieHeader))
        return Credentials(
            userId: dto.userId,
            workosId: dto.workosId,
            email: dto.email,
            teamId: dto.teamId ?? 0,
            cookieHeader: cookieHeader,
            isEnterpriseUser: dto.isEnterpriseUser
        )
    }

    public func fetchUsageSummary(cookieHeader: String) async throws -> AIUsageTrackerModel.UsageSummary {
        let dto: CursorUsageSummaryResponse = try await self.performRequest(CursorUsageSummaryAPI(cookieHeader: cookieHeader))
        
        // Parse the ISO 8601 billing cycle dates
        let dateFormatter = ISO8601DateFormatter()
        let billingCycleStart = dateFormatter.date(from: dto.billingCycleStart) ?? Date()
        let billingCycleEnd = dateFormatter.date(from: dto.billingCycleEnd) ?? Date()
        
        // Map plan usage totals
        let planUsage = AIUsageTrackerModel.PlanUsage(
            used: dto.individualUsage.plan.used,
            limit: dto.individualUsage.plan.limit,
            remaining: dto.individualUsage.plan.remaining,
            breakdown: AIUsageTrackerModel.PlanBreakdown(
                included: dto.individualUsage.plan.breakdown.included,
                bonus: dto.individualUsage.plan.breakdown.bonus,
                total: dto.individualUsage.plan.breakdown.total
            )
        )
        
        // Map on-demand usage when present
        let onDemandUsage: AIUsageTrackerModel.OnDemandUsage? = {
            guard let individualOnDemand = dto.individualUsage.onDemand else { return nil }
            if individualOnDemand.used > 0 || individualOnDemand.limit > 0 {
                return AIUsageTrackerModel.OnDemandUsage(
                    used: individualOnDemand.used,
                    limit: individualOnDemand.limit,
                    remaining: individualOnDemand.remaining
                )
            }
            return nil
        }()
        
        // Map individual usage structure
        let individualUsage = AIUsageTrackerModel.IndividualUsage(
            plan: planUsage,
            onDemand: onDemandUsage
        )
        
        // Map team usage structure when the payload includes it
        let teamUsage: AIUsageTrackerModel.TeamUsage? = {
            guard let teamUsageData = dto.teamUsage,
                  let teamOnDemand = teamUsageData.onDemand else { return nil }
            if teamOnDemand.used > 0 || teamOnDemand.limit > 0 {
                return AIUsageTrackerModel.TeamUsage(
                    onDemand: AIUsageTrackerModel.OnDemandUsage(
                        used: teamOnDemand.used,
                        limit: teamOnDemand.limit,
                        remaining: teamOnDemand.remaining
                    )
                )
            }
            return nil
        }()
        
        // Resolve the membership type enumeration
        let membershipType = AIUsageTrackerModel.MembershipType(rawValue: dto.membershipType) ?? .free
        
        return AIUsageTrackerModel.UsageSummary(
            billingCycleStart: billingCycleStart,
            billingCycleEnd: billingCycleEnd,
            membershipType: membershipType,
            limitType: dto.limitType,
            individualUsage: individualUsage,
            teamUsage: teamUsage
        )
    }

    public func fetchFilteredUsageEvents(
        startDateMs: String,
        endDateMs: String,
        userId: Int,
        page: Int,
        cookieHeader: String
    ) async throws -> AIUsageTrackerModel.FilteredUsageHistory {
        let dto: CursorFilteredUsageResponse = try await self.performRequest(
            CursorFilteredUsageAPI(
                startDateMs: startDateMs,
                endDateMs: endDateMs,
                userId: userId,
                page: page,
                cookieHeader: cookieHeader
            )
        )
        let events: [AIUsageTrackerModel.UsageEvent] = (dto.usageEventsDisplay ?? []).map { e in
            let tokenUsage = AIUsageTrackerModel.TokenUsage(
                outputTokens: e.tokenUsage.outputTokens,
                inputTokens: e.tokenUsage.inputTokens,
                totalCents: e.tokenUsage.totalCents ?? 0.0,
                cacheWriteTokens: e.tokenUsage.cacheWriteTokens,
                cacheReadTokens: e.tokenUsage.cacheReadTokens
            )
            
            // Derive the request count from token usage, defaulting to 1 when metadata is missing
            let requestCount = Self.calculateRequestCount(from: e.tokenUsage)
            
            return AIUsageTrackerModel.UsageEvent(
                occurredAtMs: e.timestamp,
                modelName: e.model,
                kind: e.kind,
                requestCostCount: requestCount,
                usageCostDisplay: e.usageBasedCosts,
                usageCostCents: Self.parseCents(fromDollarString: e.usageBasedCosts),
                isTokenBased: e.isTokenBasedCall,
                userDisplayName: e.owningUser,
                cursorTokenFee: e.cursorTokenFee,
                tokenUsage: tokenUsage
            )
        }
        return AIUsageTrackerModel.FilteredUsageHistory(totalCount: dto.totalUsageEventsCount ?? 0, events: events)
    }

    public func fetchTeamFreeUsageCents(teamId: Int, userId: Int, cookieHeader: String) async throws -> Int {
        let dto: CursorTeamSpendResponse = try await self.performRequest(
            CursorGetTeamSpendAPI(
                teamId: teamId,
                page: 1,
                // pageSize is hardcoded to 100
                sortBy: "name",
                sortDirection: "asc",
                cookieHeader: cookieHeader
            )
        )

        guard let me = dto.teamMemberSpend.first(where: { $0.userId == userId }) else {
            return 0
        }

        let included = me.includedSpendCents ?? 0
        let overrideDollars = me.hardLimitOverrideDollars ?? 0
        let freeCents = max(included - overrideDollars * 100, 0)
        return freeCents
    }

    public func fetchUserAnalytics(
        userId: Int,
        startDateMs: String,
        endDateMs: String,
        cookieHeader: String
    ) async throws -> AIUsageTrackerModel.UserAnalytics {
        let dto: CursorUserAnalyticsResponse = try await self.performRequest(
            CursorUserAnalyticsAPI(
                userId: userId,
                startDateMs: startDateMs,
                endDateMs: endDateMs,
                cookieHeader: cookieHeader
            )
        )
        
        // Convert analytics into the four chart data structures the UI consumes
        return AIUsageTrackerModel.UserAnalytics(
            usageChart: mapToUsageChart(dto.dailyMetrics),
            modelUsageChart: mapToModelUsageChart(dto.dailyMetrics),
            tabAcceptChart: mapToTabAcceptChart(dto.dailyMetrics),
            agentLineChangesChart: mapToAgentLineChangesChart(dto.dailyMetrics)
        )
    }
    
    // MARK: - Private Chart Mapping Methods
    
    /// Build the stacked bar chart for subscription vs usage-based requests
    private func mapToUsageChart(_ metrics: [CursorDailyMetric]) -> AIUsageTrackerModel.UsageChartData {
        let dataPoints = metrics.compactMap { metric -> AIUsageTrackerModel.UsageChartData.DataPoint? in
            let subscriptionReqs = metric.subscriptionIncludedReqs ?? 0
            let usageBasedReqs = metric.usageBasedReqs ?? 0
            
            // Skip days with no activity
            guard subscriptionReqs > 0 || usageBasedReqs > 0 else {
                return nil
            }
            
            let dateLabel = formatDateLabel(metric.date)
            return AIUsageTrackerModel.UsageChartData.DataPoint(
                date: metric.date,
                dateLabel: dateLabel,
                subscriptionReqs: subscriptionReqs,
                usageBasedReqs: usageBasedReqs
            )
        }
        return AIUsageTrackerModel.UsageChartData(dataPoints: dataPoints)
    }
    
    /// Aggregate model usage across the entire range for the pie chart
    private func mapToModelUsageChart(_ metrics: [CursorDailyMetric]) -> AIUsageTrackerModel.ModelUsageChartData {
        // Combine all model usage tallies
        var modelCounts: [String: Int] = [:]
        
        for metric in metrics {
            guard let modelUsage = metric.modelUsage else { continue }
            for model in modelUsage {
                modelCounts[model.name, default: 0] += model.count
            }
        }
        
        // Calculate totals and percentages
        let totalCount = modelCounts.values.reduce(0, +)
        
        let modelDistribution = modelCounts.map { name, count -> AIUsageTrackerModel.ModelUsageChartData.ModelShare in
            let percentage = totalCount > 0 ? (Double(count) / Double(totalCount)) * 100.0 : 0.0
            return AIUsageTrackerModel.ModelUsageChartData.ModelShare(
                id: name,
                modelName: name,
                count: count,
                percentage: percentage
            )
        }.sorted { $0.count > $1.count } // Sort by count descending
        
        return AIUsageTrackerModel.ModelUsageChartData(modelDistribution: modelDistribution)
    }
    
    /// Build the accepted-tab bar chart
    private func mapToTabAcceptChart(_ metrics: [CursorDailyMetric]) -> AIUsageTrackerModel.TabAcceptChartData {
        let dataPoints = metrics.compactMap { metric -> AIUsageTrackerModel.TabAcceptChartData.DataPoint? in
            guard let acceptedCount = metric.totalTabsAccepted, acceptedCount > 0 else {
                return nil
            }
            let dateLabel = formatDateLabel(metric.date)
            return AIUsageTrackerModel.TabAcceptChartData.DataPoint(
                date: metric.date,
                dateLabel: dateLabel,
                acceptedCount: acceptedCount
            )
        }
        return AIUsageTrackerModel.TabAcceptChartData(dataPoints: dataPoints)
    }
    
    /// Build the agent line-change chart
    private func mapToAgentLineChangesChart(_ metrics: [CursorDailyMetric]) -> AIUsageTrackerModel.AgentLineChangesChartData {
        let dataPoints = metrics.compactMap { metric -> AIUsageTrackerModel.AgentLineChangesChartData.DataPoint? in
            let linesAdded = metric.linesAdded ?? 0
            let linesDeleted = metric.linesDeleted ?? 0
            let acceptedLinesAdded = metric.acceptedLinesAdded ?? 0
            let acceptedLinesDeleted = metric.acceptedLinesDeleted ?? 0
            
            let suggestedLines = linesAdded + linesDeleted
            let acceptedLines = acceptedLinesAdded + acceptedLinesDeleted
            
            // Skip if there is no suggested or accepted work
            guard suggestedLines > 0 || acceptedLines > 0 else {
                return nil
            }
            
            let dateLabel = formatDateLabel(metric.date)
            return AIUsageTrackerModel.AgentLineChangesChartData.DataPoint(
                date: metric.date,
                dateLabel: dateLabel,
                suggestedLines: suggestedLines,
                acceptedLines: acceptedLines
            )
        }
        return AIUsageTrackerModel.AgentLineChangesChartData(dataPoints: dataPoints)
    }
    
    /// Format a millisecond timestamp into an `MM/dd` label
    private func formatDateLabel(_ dateString: String) -> String {
        guard let timestamp = Double(dateString),
              timestamp > 0 else {
            return ""
        }
        
        let date = Date(timeIntervalSince1970: timestamp / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

private extension DefaultCursorService {
    static func parseCents(fromDollarString s: String) -> Int {
        // "$0.04" -> 4
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = trimmed.firstIndex(where: { ($0 >= "0" && $0 <= "9") || $0 == "." }) else { return 0 }
        let numberPart = trimmed[idx...]
        guard let value = Double(numberPart) else { return 0 }
        return Int((value * 100.0).rounded())
    }
    
    static func calculateRequestCount(from tokenUsage: CursorTokenUsage) -> Int {
        // Estimate request counts from token usage metadata
        // If input or output tokens are present we count the record as a request
        let hasOutputTokens = (tokenUsage.outputTokens ?? 0) > 0
        let hasInputTokens = (tokenUsage.inputTokens ?? 0) > 0
        
        if hasOutputTokens || hasInputTokens {
            // When tokens are present we guarantee at least one request
            return 1
        } else {
            // Otherwise fall back to one request to cover cache hits or atypical calls
            return 1
        }
    }
}
