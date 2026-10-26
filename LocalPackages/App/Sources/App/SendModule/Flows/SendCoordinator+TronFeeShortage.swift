import KeeperCore
import TKLocalize
import TronSwift
import UIKit

extension SendCoordinator {
    func presentTronFeeShortage(
        _ shortage: TronFeeShortage,
        wallet: Wallet,
        amountFormatter: AmountFormatter,
        from viewController: UIViewController,
        onRefresh: @escaping () -> Void
    ) {
        let symbol = TRX.symbol
        let network = MultichainChain.tron.shortDisplayTitle
        let depositButtonTitle = TKLocales.Multichain.InsufficientNativeFee.deposit(symbol)
        let depositTRX: () -> Void = { [weak self] in
            self?.handleFeeRefillRequest(
                extraType: .gasless(token: TronUSDTFeeOptionsResolver.trxFeeToken),
                onRefresh: onRefresh
            )
        }

        guard shortage.isBatteryOffered else {
            let walletTitle = InsufficientFeePopupContent.walletTitle(for: wallet)
            let required = amountFormatter.format(amount: shortage.requiredTRX, fractionDigits: TRX.fractionDigits)
            PopupContentPresenter.presentInsufficientFee(
                content: InsufficientFeePopupContent(
                    title: TKLocales.Multichain.InsufficientNativeFee.title(symbol, network, walletTitle.argument),
                    caption: TKLocales.Multichain.InsufficientNativeFee.caption(required, symbol),
                    primaryButtonTitle: depositButtonTitle,
                    walletIcon: walletTitle.icon,
                    walletName: walletTitle.name,
                    walletNamePlaceholder: walletTitle.namePlaceholder
                ),
                from: viewController,
                onPrimary: depositTRX
            )
            return
        }

        let required = amountFormatter.format(
            amount: shortage.requiredTRX,
            fractionDigits: TRX.fractionDigits,
            accessory: .tokenSymbol(symbol)
        )
        PopupContentPresenter.presentBatteryFeeShortage(
            content: BatteryFeeShortagePopupContent(
                title: TKLocales.MultichainSwap.Screen.Confirm.BatteryFeeShortage.title(symbol),
                caption: TKLocales.TransactionConfirmation.BatteryFeeShortage.caption(network, required, symbol),
                rechargeButtonTitle: TKLocales.MultichainSwap.Screen.Confirm.BatteryFeeShortage.rechargeBattery,
                depositButtonTitle: depositButtonTitle
            ),
            from: viewController,
            onRecharge: { [weak self] in
                self?.handleFeeRefillRequest(extraType: .battery, onRefresh: onRefresh)
            },
            onDeposit: depositTRX
        )
    }
}
