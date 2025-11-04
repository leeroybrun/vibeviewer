import Foundation

/// Cursor API response describing per-user analytics metrics.
struct CursorUserAnalyticsResponse: Codable, Sendable, Equatable {
    let dailyMetrics: [CursorDailyMetric]
    let period: CursorAnalyticsPeriod
    let applyLinesRank: Int?
    let tabsAcceptedRank: Int?
    let totalTeamMembers: Int?
    let totalApplyLines: Int?
    let teamAverageApplyLines: Int?
    let totalTabsAccepted: Int?
    let teamAverageTabsAccepted: Int?
    let totalMembersInTeam: Int?
}

/// Cursor API payload representing daily metrics.
struct CursorDailyMetric: Codable, Sendable, Equatable {
    let date: String
    let activeUsers: Int?
    let linesAdded: Int?
    let linesDeleted: Int?
    let acceptedLinesAdded: Int?
    let acceptedLinesDeleted: Int?
    let totalApplies: Int?
    let totalAccepts: Int?
    let totalRejects: Int?
    let totalTabsShown: Int?
    let totalTabsAccepted: Int?
    let chatRequests: Int?
    let agentRequests: Int?
    let cmdkUsages: Int?
    let subscriptionIncludedReqs: Int?
    let usageBasedReqs: Int?
    let modelUsage: [CursorModelUsageCount]?
    let extensionUsage: [CursorExtensionUsageCount]?
    let tabExtensionUsage: [CursorExtensionUsageCount]?
    let clientVersionUsage: [CursorClientVersionUsageCount]?
}

/// Cursor API payload describing per-model usage counts.
struct CursorModelUsageCount: Codable, Sendable, Equatable {
    let name: String
    let count: Int
}

/// Cursor API payload for extension usage counts.
struct CursorExtensionUsageCount: Codable, Sendable, Equatable {
    let name: String?
    let count: Int
}

/// Cursor API payload for client version usage counts.
struct CursorClientVersionUsageCount: Codable, Sendable, Equatable {
    let name: String
    let count: Int
}

/// Cursor API payload for the analytics period window.
struct CursorAnalyticsPeriod: Codable, Sendable, Equatable {
    let startDate: String
    let endDate: String
}

