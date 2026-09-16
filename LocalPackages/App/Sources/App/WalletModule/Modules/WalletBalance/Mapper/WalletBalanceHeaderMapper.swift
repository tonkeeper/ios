import BigInt
import KeeperCore
import SwiftUI
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

    func mapTotalBalanceAmount(
        totalBalance: TotalBalance?,
        color: TKColor
    ) -> BalanceViewContent.Balance {
        guard let totalBalance else {
            return BalanceViewContent.Balance(text: "-", color: color)
        }

        return mapFiatBalanceAmount(
            amount: totalBalance.amount,
            currency: totalBalance.currency,
            color: color
        )
    }

    func mapFiatBalanceAmount(
        amount: Decimal,
        currency: Currency,
        color: TKColor
    ) -> BalanceViewContent.Balance {
        BalanceViewContent.Balance(
            amount: mapBalanceHeaderAmountFormat(
                amountFormatter.formatBalanceHeaderAmount(
                    decimal: amount,
                    accessory: .fiat(currency)
                ),
                color: color
            )
        )
    }

    func mapBalanceHeaderAmountFormat(
        _ format: BalanceHeaderAmountFormat,
        color: TKColor
    ) -> BalanceViewContent.Balance.Amount {
        BalanceViewContent.Balance.Amount(
            leadingText: format.leadingAccessory,
            trailingText: format.trailingAccessory,
            textParts: format.numberParts.map { part in
                BalanceViewContent.Balance.Amount.TextPart(
                    text: part.text,
                    role: mapRole(part.role)
                )
            },
            textSize: mapTextSize(format.textSize),
            tooltipText: format.tooltipText,
            accessibilityText: format.fullText,
            color: color
        )
    }

    private func mapRole(
        _ role: BalanceHeaderAmountFormat.NumberPart.Role
    ) -> BalanceViewContent.Balance.Amount.TextPart.Role {
        switch role {
        case .primary:
            return .primary
        case .fraction:
            return .fraction
        }
    }

    private func mapTextSize(
        _ textSize: BalanceHeaderAmountFormat.TextSize
    ) -> BalanceViewContent.Balance.Amount.TextSize {
        switch textSize {
        case .regular:
            return .regular
        case .reduced:
            return .reduced
        }
    }
}
