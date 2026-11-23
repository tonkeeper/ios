import SwiftUI
import WidgetKit

@main
struct KeeperWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 17.0, *) {
            BalanceWidget()
            ActionsWidget()
            RateWidget()
            RateChartWidget()
            WatchlistWidget()
        }
        if #available(iOS 16.2, *) {
            TransactionLiveActivityWidget()
        }
    }
}
