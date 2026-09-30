import SwiftUI
import TKUIKit

struct RateWidgetChartView: View {
    let chartData: RateWidgetEntry.ChartData

    var body: some View {
        TKLineChartCanvasView(chartData: chartData.data)
    }
}
