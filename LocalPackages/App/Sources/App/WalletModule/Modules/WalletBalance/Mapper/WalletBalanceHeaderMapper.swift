import BigInt
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

struct WalletBalanceHeaderMapper {
    private let amountFormatter: AmountFormatter
    private let dateFormatter: DateFormatter

    init(
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter
    ) {
        self.amountFormatter = amountFormatter
        self.dateFormatter = dateFormatter
    }

    func makeUpdatedDate(_ date: Date) -> String {
        dateFormatter.dateFormat = "d MMM HH:mm"
        return dateFormatter.string(from: date)
    }

    func mapTotalBalance(totalBalance: TotalBalance?) -> String {
        if let totalBalance = totalBalance {
            return amountFormatter.format(
                decimal: totalBalance.amount,
                accessory: .currency(totalBalance.currency),
                style: .compact
            )
        } else {
            return "-"
        }
    }
}
