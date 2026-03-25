import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

struct InfoPopupBottomSheetConfigurationBuilder {
    private let amountFormatter: AmountFormatter

    init(amountFormatter: AmountFormatter) {
        self.amountFormatter = amountFormatter
    }

    func insufficientTokenConfiguration(
        walletLabel: String?,
        caption: String? = nil,
        tokenSymbol: String,
        tokenFractionalDigits: Int,
        required: BigUInt,
        available: BigUInt,
        buttons: [TKButton.Configuration]
    ) -> InfoPopupBottomSheetViewController.Configuration {
        let requiredFormattedAmount = amountFormatter.format(
            amount: required,
            fractionDigits: tokenFractionalDigits,
            accessory: .symbol(tokenSymbol)
        )

        let availableFormattedAmount = amountFormatter.format(
            amount: available,
            fractionDigits: tokenFractionalDigits,
            accessory: .symbol(tokenSymbol)
        )

        let title: String
        if let walletLabel {
            title = TKLocales.InsufficientFunds.Wallet.title(walletLabel)
        } else {
            title = TKLocales.InsufficientFunds.title
        }

        let resultCaption = caption ?? TKLocales.InsufficientFunds.toBePaidYourBalance(
            requiredFormattedAmount, availableFormattedAmount
        )

        return .init(
            image: .TKUIKit.Icons.Size84.exclamationmarkCircle,
            imageTintColor: .Icon.secondary,
            title: title,
            caption: resultCaption,
            bodyContent: nil,
            buttons: buttons
        )
    }

    func commonConfiguration(
        title: String,
        caption: String,
        body: [InfoPopupBottomSheetViewController.Configuration.BodyView]? = nil,
        buttons: [TKButton.Configuration]
    ) -> InfoPopupBottomSheetViewController.Configuration {
        InfoPopupBottomSheetViewController.Configuration(
            image: nil,
            imageTintColor: nil,
            title: title,
            caption: caption,
            bodyContent: body,
            buttons: buttons
        )
    }
}
