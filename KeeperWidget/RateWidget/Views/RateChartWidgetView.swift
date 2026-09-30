import SwiftUI
import WidgetKit

struct RateChartWidgetView: View {
    let entry: RateWidgetEntry

    @Environment(\.widgetFamily) var family: WidgetFamily

    var body: some View {
        switch family {
        case .systemSmall:
            HomeScreenSmallRateChartWidgetView(entry: entry)
        case .systemMedium:
            HomeScreenMediumRateChartWidgetView(entry: entry)
        default:
            EmptyView()
        }
    }
}
