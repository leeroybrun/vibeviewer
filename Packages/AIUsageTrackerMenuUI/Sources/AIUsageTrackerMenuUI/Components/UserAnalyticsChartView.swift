import SwiftUI
import AIUsageTrackerModel
import AIUsageTrackerCore

@MainActor
public struct UserAnalyticsChartView: View {
    let analytics: UserAnalytics
    
    @State private var selectedChartType: ChartType = .usage
    @State private var showChartTypePicker = false
    
    public init(analytics: UserAnalytics) {
        self.analytics = analytics
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and chart picker.
            titleView
            
            // Render the chart that matches the current selection.
            chartContentView
                .transition(.blurReplace)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: selectedChartType)
    }
    
    // MARK: - Title View
    
    private var titleView: some View {
        Button(action: {
            showChartTypePicker.toggle()
        }) {
            HStack(spacing: 6) {
                Text(selectedChartType.rawValue)
                    .font(.app(.satoshiBold, size: 14))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showChartTypePicker, arrowEdge: .bottom) {
            Picker("Chart Type", selection: $selectedChartType) {
                ForEach(ChartType.allCases, id: \.self) { chartType in
                    Text(chartType.rawValue).tag(chartType)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .menuActionDismissBehavior(.enabled)
            .padding()
        }
        .maxFrame(true, false, alignment: .leading)
    }
    
    // MARK: - Chart Content View
    
    @ViewBuilder
    private var chartContentView: some View {
        switch selectedChartType {
        case .usage:
            UsageBarChartView(data: analytics.usageChart)
        case .modelUsage:
            ModelUsagePieChartView(data: analytics.modelUsageChart)
        case .tabAccept:
            TabAcceptBarChartView(data: analytics.tabAcceptChart)
        case .agentLineChanges:
            AgentLineChangesChartView(data: analytics.agentLineChangesChart)
        }
    }
}
