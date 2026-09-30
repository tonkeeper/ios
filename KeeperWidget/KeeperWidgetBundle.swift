import SwiftUI
import WidgetKit

@main
struct KeeperWidgetBundle: WidgetBundle {
    var body: some Widget {
        RateChartWidget()
        RateWidget()
        BalanceWidget()
    }
}
