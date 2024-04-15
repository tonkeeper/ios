import SwiftUI
import WidgetKit
import KeeperCore

struct BalanceWidgetView: View {
  let entry: BalanceWidgetEntry
  
  @Environment(\.widgetFamily) var family: WidgetFamily
  
  @ViewBuilder
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
