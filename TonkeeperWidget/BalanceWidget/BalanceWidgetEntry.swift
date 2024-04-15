import WidgetKit
import KeeperCore

struct BalanceWidgetEntry: TimelineEntry {
  let date: Date
  let loadResult: Result<BalanceWidgetController.Model, BalanceWidgetController.Error>
  
  init(date: Date,
       loadResult: Result<BalanceWidgetController.Model, BalanceWidgetController.Error>) {
    self.date = date
    self.loadResult = loadResult
  }
}
