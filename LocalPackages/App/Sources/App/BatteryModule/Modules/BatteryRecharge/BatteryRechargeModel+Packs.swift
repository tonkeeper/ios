import AppUI
import Foundation
import KeeperCore
import TKCore
import TKLocalize

extension BatteryRechargeModel {
    /// The prefilled options, most charges first.
    var prefilledOptions: [OptionItem.Prefilled] {
        optionsItems
            .compactMap { if case let .prefilled(prefilled) = $0 { prefilled } else { nil } }
            .sorted { $0.chargesCount > $1.chargesCount }
    }

    /// The options as packs: the price as the title, the most charges tagged as the best value, then the
    /// manual amount.
    func packs(
        selectedId: String?,
        amountFormatter: AmountFormatter
    ) -> [BatteryRefillViewState.Pack] {
        let customId = OptionItem.custom.identifier
        guard optionsItems.contains(where: { $0.identifier == customId }) else { return [] }
        let prefilled = prefilledOptions
        let packs = prefilled.enumerated().map { index, option in
            BatteryRefillViewState.Pack(
                id: option.identifier,
                title: amountFormatter.format(
                    amount: option.tokenAmount,
                    fractionDigits: option.tokenDigits,
                    accessory: .tokenSymbol(option.tokenSymbol),
                    style: .compact
                ),
                caption: "\(amountFormatter.format(decimal: Decimal(option.chargesCount), style: .compact)) "
                    + TKLocales.Battery.Refill.chargesCount(count: option.chargesCount),
                icon: .fill(option.batteryPercent),
                tag: index == 0 && prefilled.count > 1 ? TKLocales.Battery.Refill.bestValue : nil,
                isEnabled: option.isEnable,
                isSelected: option.identifier == selectedId
            )
        }
        let other = BatteryRefillViewState.Pack(
            id: customId,
            title: TKLocales.Battery.Recharge.СustomInput.title,
            caption: TKLocales.Battery.Recharge.СustomInput.caption,
            icon: .other,
            isSelected: customId == selectedId
        )
        return packs + [other]
    }
}
