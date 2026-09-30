import KeeperCore
import WidgetKit

struct BalanceWidgetEntry: TimelineEntry {
    let date: Date
    let loadResult: Result<BalanceWidgetController.Model, BalanceWidgetController.Error>
}
