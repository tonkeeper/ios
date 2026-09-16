import KeeperCore
import TKLocalize
import TKUIKit
import TronSwift

enum TronUsdtInsufficientTrxSheet {
    static func configuration(
        for snapshot: TronUsdtFeesSnapshot,
        amountFormatter: AmountFormatter,
        onGetTrx: @escaping () -> Void
    ) -> InfoPopupBottomSheetViewController.Configuration {
        let getTrxButton = {
            var button = TKButton.Configuration.actionButtonConfiguration(
                category: .secondary,
                size: .large
            )
            button.content = .init(title: .plainString(TKLocales.TronUsdtFees.Common.Buttons.getTrx))
            button.action = onGetTrx
            return button
        }()
        return InfoPopupBottomSheetViewController.Configuration(
            image: .TKUIKit.Icons.Size84.exclamationmarkCircle,
            imageTintColor: .Icon.secondary,
            title: TKLocales.TronUsdtFees.InsufficientPopup.title,
            caption: TKLocales.TronUsdtFees.InsufficientPopup.caption(
                amountFormatter.format(
                    amount: snapshot.requiredTRX,
                    fractionDigits: TRX.fractionDigits,
                    accessory: .none
                ),
                amountFormatter.format(
                    amount: snapshot.trxBalance,
                    fractionDigits: TRX.fractionDigits,
                    accessory: .none
                )
            ),
            bodyContent: nil,
            buttons: [getTrxButton]
        )
    }
}
