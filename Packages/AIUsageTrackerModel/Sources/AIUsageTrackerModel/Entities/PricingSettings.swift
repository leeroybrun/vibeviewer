import Foundation

public struct ModelPricing: Codable, Sendable, Equatable {
    public var inputCostPerThousandTokensCents: Double
    public var outputCostPerThousandTokensCents: Double
    public var cacheWriteCostPerThousandTokensCents: Double?
    public var cacheReadCostPerThousandTokensCents: Double?

    public init(
        inputCostPerThousandTokensCents: Double,
        outputCostPerThousandTokensCents: Double,
        cacheWriteCostPerThousandTokensCents: Double? = nil,
        cacheReadCostPerThousandTokensCents: Double? = nil
    ) {
        self.inputCostPerThousandTokensCents = inputCostPerThousandTokensCents
        self.outputCostPerThousandTokensCents = outputCostPerThousandTokensCents
        self.cacheWriteCostPerThousandTokensCents = cacheWriteCostPerThousandTokensCents
        self.cacheReadCostPerThousandTokensCents = cacheReadCostPerThousandTokensCents
    }
}

public struct PricingSettings: Codable, Sendable, Equatable {
    public var cursorPlanMonthlyCents: Int
    public var openAIPlanMonthlyCents: Int
    public var anthropicPlanMonthlyCents: Int
    public var googlePlanMonthlyCents: Int
    public var perModelOverrides: [String: ModelPricing]

    public init(
        cursorPlanMonthlyCents: Int = 2000,
        openAIPlanMonthlyCents: Int = 0,
        anthropicPlanMonthlyCents: Int = 0,
        googlePlanMonthlyCents: Int = 0,
        perModelOverrides: [String: ModelPricing] = [:]
    ) {
        self.cursorPlanMonthlyCents = cursorPlanMonthlyCents
        self.openAIPlanMonthlyCents = openAIPlanMonthlyCents
        self.anthropicPlanMonthlyCents = anthropicPlanMonthlyCents
        self.googlePlanMonthlyCents = googlePlanMonthlyCents
        self.perModelOverrides = perModelOverrides
    }
}
