import SwiftUI
import WidgetKit

struct RateWidgetView: View {
    let entry: RateWidgetEntry

    @Environment(\.widgetFamily) var family: WidgetFamily

    var body: some View {
        switch family {
        case .systemSmall:
            HomeScreenSmallRateWidgetView(entry: entry)
        default:
            EmptyView()
        }
    }
}
