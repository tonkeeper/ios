import KeeperCore
import SwiftUI
import WidgetKit

struct BalanceWidgetView: View {
    let entry: BalanceWidgetEntry

    @Environment(\.widgetFamily) var family: WidgetFamily

    var widgetView: some View {
        HomeScreenBalanceWidget(entry: entry) { model in
            switch family {
            case .systemSmall:
                HomeScreenBalanceWidgetSmallContentView(model: model)
            case .systemMedium:
                HomeScreenBalanceWidgetMediumContentView(model: model)
            default:
                EmptyView()
            }
        }
    }

    var body: some View {
        widgetView
    }
}
