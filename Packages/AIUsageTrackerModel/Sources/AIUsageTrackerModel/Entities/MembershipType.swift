import Foundation

/// Membership types supported by Cursor subscriptions.
public enum MembershipType: String, Sendable, Equatable, Codable {
    case enterprise = "enterprise"
    case freeTrial = "free_trial"
    case pro = "pro"
    case proPlus = "pro_plus"
    case ultra = "ultra"
    case free = "free"
    
    /// Human readable membership name.
    /// - Parameters:
    ///   - subscriptionStatus: active status on the billing record.
    ///   - isEnterprise: flag used to distinguish enterprise vs. regular team plans.
    /// - Returns: localized display name.
    public func displayName(
        subscriptionStatus: SubscriptionStatus? = nil,
        isEnterprise: Bool = false
    ) -> String {
        switch self {
        case .enterprise:
            return isEnterprise ? "Enterprise" : "Team Plan"
        case .freeTrial:
            return "Pro Trial"
        case .pro:
            return subscriptionStatus == .trialing ? "Pro Trial" : "Pro Plan"
        case .proPlus:
            return subscriptionStatus == .trialing ? "Pro+ Trial" : "Pro+ Plan"
        case .ultra:
            return "Ultra Plan"
        case .free:
            return "Free Plan"
        }
    }
}

/// Subscription lifecycle states reported by Cursor.
public enum SubscriptionStatus: String, Sendable, Equatable, Codable {
    case trialing = "trialing"
    case active = "active"
    case canceled = "canceled"
    case pastDue = "past_due"
    case unpaid = "unpaid"
}

