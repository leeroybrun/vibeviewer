import SwiftUI
import AIUsageTrackerCore
import AIUsageTrackerModel

@MainActor
struct DashboardSummaryView: View {
    let snapshot: DashboardSnapshot?

    var body: some View {
        Group {
            if let snapshot {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email: \(snapshot.email)")
                    Text("Total requests (all models): \(snapshot.totalRequestsAllModels)")
                    Text("Usage Spending ($): \(snapshot.spendingCents.dollarStringFromCents)")
                    Text("Plan budget ($): \(snapshot.hardLimitDollars)")
                    
                    if let usageSummary = snapshot.usageSummary {
                        Text("Plan Usage: \(usageSummary.individualUsage.plan.used)/\(usageSummary.individualUsage.plan.limit)")
                        if let onDemand = usageSummary.individualUsage.onDemand {
                            Text("On-Demand Usage: \(onDemand.used)/\(onDemand.limit)")
                        }
                    }
                }
            } else {
                Text("Not signed in. Please log in to Cursor.")
            }
        }
    }
}
