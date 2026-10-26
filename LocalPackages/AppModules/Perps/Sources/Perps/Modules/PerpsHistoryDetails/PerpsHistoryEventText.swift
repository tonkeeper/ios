import PerpsModels
import TKLocalize
import TKUIKit
import UIKit

/// Row and detail wording for a position event, shared with the wallet history rows.
enum PerpsHistoryEventText {
    static func icon(_ kind: PerpsHistoryEvent.Kind) -> UIImage {
        switch kind {
        case .opened, .increased: .TKUIKit.Icons.Size28.openLock
        case .reduced, .closed: .TKUIKit.Icons.Size28.lock
        case .takeProfit: .TKUIKit.Icons.Size28.arrowup
        case .stopLoss: .TKUIKit.Icons.Size28.arrowdown
        case .liquidated: .TKUIKit.Icons.Size28.fire
        }
    }

    static func title(_ event: PerpsHistoryEvent) -> String {
        typealias Text = TKLocales.MultichainHistory.Perps
        switch (event.kind, event.side) {
        case (.opened, .long): return Text.openedLong
        case (.opened, .short): return Text.openedShort
        case (.opened, nil): return Text.opened
        case (.increased, .long): return Text.increasedLong
        case (.increased, .short): return Text.increasedShort
        case (.increased, nil): return Text.increased
        case (.reduced, .long): return Text.reducedLong
        case (.reduced, .short): return Text.reducedShort
        case (.reduced, nil): return Text.reduced
        case (.closed, .long): return Text.closedLong
        case (.closed, .short): return Text.closedShort
        case (.closed, nil): return Text.closed
        case (.liquidated, .long): return Text.liquidatedLong
        case (.liquidated, .short): return Text.liquidatedShort
        case (.liquidated, nil): return Text.liquidated
        case (.takeProfit, _): return Text.takeProfitExecuted
        case (.stopLoss, _): return Text.stopLossExecuted
        }
    }

    static func detailsDate(_ event: PerpsHistoryEvent, date: String) -> String {
        typealias Text = TKLocales.Perps.HistoryDetails
        switch (event.kind, event.side) {
        case (.opened, .long): return Text.openedLong(date)
        case (.opened, .short): return Text.openedShort(date)
        case (.opened, nil): return Text.opened(date)
        case (.increased, .long): return Text.increasedLong(date)
        case (.increased, .short): return Text.increasedShort(date)
        case (.increased, nil): return Text.increased(date)
        case (.reduced, .long): return Text.reducedLong(date)
        case (.reduced, .short): return Text.reducedShort(date)
        case (.reduced, nil): return Text.reduced(date)
        case (.closed, .long): return Text.closedLong(date)
        case (.closed, .short): return Text.closedShort(date)
        case (.closed, nil): return Text.closed(date)
        case (.liquidated, .long): return Text.liquidatedLong(date)
        case (.liquidated, .short): return Text.liquidatedShort(date)
        case (.liquidated, nil): return Text.liquidated(date)
        case (.takeProfit, _): return Text.takeProfit(date)
        case (.stopLoss, _): return Text.stopLoss(date)
        }
    }
}
