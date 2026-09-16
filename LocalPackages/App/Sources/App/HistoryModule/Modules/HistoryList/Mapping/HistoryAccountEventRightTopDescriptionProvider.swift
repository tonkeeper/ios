import Foundation
import KeeperCore

struct HistoryAccountEventRightTopDescriptionProvider: AccountEventRightTopDescriptionProvider {
    private let dateFormatter: DateFormatter

    init(dateFormatter: DateFormatter) {
        self.dateFormatter = dateFormatter
    }

    mutating func rightTopDescription(
        accountEvent: AccountEvent,
        action: AccountEventAction
    ) -> String? {
        return dateFormatter.string(from: accountEvent.date)
    }
}
