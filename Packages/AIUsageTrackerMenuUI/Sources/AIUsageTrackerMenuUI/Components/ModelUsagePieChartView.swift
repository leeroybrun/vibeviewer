import SwiftUI
import AIUsageTrackerModel
import AIUsageTrackerCore
import Charts

struct ModelUsagePieChartView: View {
    let data: ModelUsageChartData
    
    @State private var selectedAngle: Double?
    
    // Precompute each model's angular range.
    private let modelRanges: [(id: String, range: Range<Double>)]
    private let totalCount: Int
    
    // Purple palette from light to dark (10-100).
    private let tealColors: [Color] = [
        Color(hex: "f6f2ff"), // Purple 10
        Color(hex: "e8daff"), // Purple 20
        Color(hex: "d4bbff"), // Purple 30
        Color(hex: "be95ff"), // Purple 40
        Color(hex: "a56eff"), // Purple 50
        Color(hex: "8a3ffc"), // Purple 60
        Color(hex: "6929c4"), // Purple 70
        Color(hex: "491d8b"), // Purple 80
        Color(hex: "31135e"), // Purple 90
        Color(hex: "1c0f30"), // Purple 100
    ]
    
    init(data: ModelUsageChartData) {
        self.data = data
        var total = 0
        modelRanges = data.modelDistribution.map { model in
            let newTotal = total + model.count
            let result = (id: model.id, range: Double(total)..<Double(newTotal))
            total = newTotal
            return result
        }
        self.totalCount = total
    }
    
    // Resolve the selected model based on the active angle.
    private var selectedItem: ModelUsageChartData.ModelShare? {
        guard let selectedAngle else { return nil }
        if let selected = modelRanges.firstIndex(where: { $0.range.contains(selectedAngle) }) {
            return data.modelDistribution[selected]
        }
        return nil
    }
    
    // Map the percentage to the palette (higher share → darker color).
    private func colorForPercentage(_ percentage: Double) -> Color {
        // Map the 0-100 percentage range to the palette index.
        let normalizedPercentage = min(max(percentage, 0), 100) // Ensure the value stays within 0-100.
        let colorIndex = Int((normalizedPercentage / 100.0) * Double(tealColors.count - 1))
        return tealColors[min(colorIndex, tealColors.count - 1)]
    }
    
    var body: some View {
        if data.modelDistribution.isEmpty {
            emptyView
        } else {
            chartView
        }
    }
    
    private var emptyView: some View {
        Text("No data available")
            .font(.app(.satoshiRegular, size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
    }
    
    private var chartView: some View {
        Chart {
            ForEach(data.modelDistribution) { model in
                SectorMark(
                    angle: .value("Count", model.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .cornerRadius(5)
                .foregroundStyle(colorForPercentage(model.percentage))
                .opacity(selectedItem == nil || selectedItem?.id == model.id ? 1.0 : 0.5)
            }
        }
        .chartAngleSelection(value: $selectedAngle)
        .chartLegend(.hidden)
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                if let anchor = chartProxy.plotFrame {
                    let frame = geometry[anchor]
                    centerView
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .frame(height: 200)
        .animation(.easeInOut(duration: 0.2), value: selectedAngle)
    }
    
    @ViewBuilder
    private var centerView: some View {
        if let selectedItem = selectedItem {
            VStack(spacing: 4) {
                Text(selectedItem.modelName)
                    .font(.app(.satoshiMedium, size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(selectedItem.count) requests")
                    .font(.app(.satoshiBold, size: 16))
                    .foregroundStyle(.primary)
                Text(String(format: "%.1f%%", selectedItem.percentage))
                    .font(.app(.satoshiBold, size: 16))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

