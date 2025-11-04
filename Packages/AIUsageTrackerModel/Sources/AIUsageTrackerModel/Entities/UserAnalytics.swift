import Foundation

// MARK: - Chart Type Enum

/// Supported analytics chart types.
public enum ChartType: String, CaseIterable, Sendable {
    case usage = "Usage"
    case modelUsage = "Model Usage"
    case tabAccept = "Tab Accept"
    case agentLineChanges = "Agent Lines"
}

// MARK: - User Analytics

/// Aggregated user analytics data with four chart groupings.
public struct UserAnalytics: Codable, Sendable, Equatable {
    /// Usage bar chart data.
    public let usageChart: UsageChartData
    /// Model usage pie chart data.
    public let modelUsageChart: ModelUsageChartData
    /// Tab accept bar chart data.
    public let tabAcceptChart: TabAcceptChartData
    /// Agent line-change line chart data.
    public let agentLineChangesChart: AgentLineChangesChartData
    
    public init(
        usageChart: UsageChartData,
        modelUsageChart: ModelUsageChartData,
        tabAcceptChart: TabAcceptChartData,
        agentLineChangesChart: AgentLineChangesChartData
    ) {
        self.usageChart = usageChart
        self.modelUsageChart = modelUsageChart
        self.tabAcceptChart = tabAcceptChart
        self.agentLineChangesChart = agentLineChangesChart
    }
}

// MARK: - Usage Chart Data

/// Usage bar chart data.
public struct UsageChartData: Codable, Sendable, Equatable {
    /// Collection of data points.
    public let dataPoints: [DataPoint]
    
    public init(dataPoints: [DataPoint]) {
        self.dataPoints = dataPoints
    }
    
    /// Single usage data point.
    public struct DataPoint: Codable, Sendable, Equatable {
        /// Raw date as a millisecond timestamp string.
        public let date: String
        /// Display label formatted as MM/dd.
        public let dateLabel: String
        /// Request count covered by the subscription plan.
        public let subscriptionReqs: Int
        /// Request count billed on usage.
        public let usageBasedReqs: Int
        /// Combined total for the day.
        public var totalValue: Int {
            subscriptionReqs + usageBasedReqs
        }
        
        public init(date: String, dateLabel: String, subscriptionReqs: Int, usageBasedReqs: Int) {
            self.date = date
            self.dateLabel = dateLabel
            self.subscriptionReqs = subscriptionReqs
            self.usageBasedReqs = usageBasedReqs
        }
    }
}

// MARK: - Model Usage Chart Data

/// Model usage pie chart data (aggregated across all days).
public struct ModelUsageChartData: Codable, Sendable, Equatable {
    /// Distribution across models.
    public let modelDistribution: [ModelShare]
    
    public init(modelDistribution: [ModelShare]) {
        self.modelDistribution = modelDistribution
    }
    
    /// Representation of a single model share.
    public struct ModelShare: Codable, Sendable, Equatable, Identifiable {
        /// Unique identifier.
        public let id: String
        /// Model name.
        public let modelName: String
        /// Usage count.
        public let count: Int
        /// Percentage share (0-100).
        public let percentage: Double
        
        public init(id: String, modelName: String, count: Int, percentage: Double) {
            self.id = id
            self.modelName = modelName
            self.count = count
            self.percentage = percentage
        }
    }
}

// MARK: - Tab Accept Chart Data

/// Tab accept bar chart data (per day).
public struct TabAcceptChartData: Codable, Sendable, Equatable {
    /// Collection of data points.
    public let dataPoints: [DataPoint]
    
    public init(dataPoints: [DataPoint]) {
        self.dataPoints = dataPoints
    }
    
    /// Single tab-accept data point.
    public struct DataPoint: Codable, Sendable, Equatable {
        /// Raw date as a millisecond timestamp string.
        public let date: String
        /// Display label formatted as MM/dd.
        public let dateLabel: String
        /// Number of accepted tabs.
        public let acceptedCount: Int
        
        public init(date: String, dateLabel: String, acceptedCount: Int) {
            self.date = date
            self.dateLabel = dateLabel
            self.acceptedCount = acceptedCount
        }
    }
}

// MARK: - Agent Line Changes Chart Data

/// Agent line-change chart data (dual Y-axis).
public struct AgentLineChangesChartData: Codable, Sendable, Equatable {
    /// Collection of data points.
    public let dataPoints: [DataPoint]
    
    public init(dataPoints: [DataPoint]) {
        self.dataPoints = dataPoints
    }
    
    /// Single agent line-change data point.
    public struct DataPoint: Codable, Sendable, Equatable {
        /// Raw date as a millisecond timestamp string.
        public let date: String
        /// Display label formatted as MM/dd.
        public let dateLabel: String
        /// Total suggested lines (linesAdded + linesDeleted).
        public let suggestedLines: Int
        /// Total accepted lines (acceptedLinesAdded + acceptedLinesDeleted).
        public let acceptedLines: Int
        
        public init(date: String, dateLabel: String, suggestedLines: Int, acceptedLines: Int) {
            self.date = date
            self.dateLabel = dateLabel
            self.suggestedLines = suggestedLines
            self.acceptedLines = acceptedLines
        }
    }
}
