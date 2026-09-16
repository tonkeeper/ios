import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class MultichainNativeFeeShortagePopupPresenter {
    private let wallet: Wallet
    private let amountFormatter: AmountFormatter
    private let presentationGuard = MultichainNativeFeeShortagePopupPresentationGuard()

    init(
        wallet: Wallet,
        amountFormatter: AmountFormatter
    ) {
        self.wallet = wallet
        self.amountFormatter = amountFormatter
    }

    func startNewFeeCalculation() {
        presentationGuard.startNewFeeCalculation()
    }

    /// Shares `presentationGuard` with the deposit-only popup: a fee calculation that cannot be paid
    /// raises exactly one of them, never both.
    func presentBatteryOptionIfNeeded(
        shortage: MultichainNativeFeeShortage,
        from viewController: UIViewController,
        onRecharge: @escaping () -> Void,
        onDeposit: @escaping (MultichainAssetDetails) -> Void
    ) {
        guard presentationGuard.reservePresentation() else {
            return
        }

        let nativeAsset = shortage.asset
        let required = amountFormatter.format(
            amount: shortage.requiredAmount,
            fractionDigits: nativeAsset.decimals,
            accessory: .tokenSymbol(nativeAsset.symbol)
        )
        let content = BatteryFeeShortagePopupContent(
            title: TKLocales.MultichainSwap.Screen.Confirm.BatteryFeeShortage.title(nativeAsset.symbol),
            caption: TKLocales.MultichainSwap.Screen.Confirm.BatteryFeeShortage.caption(
                nativeAsset.chain?.shortDisplayTitle ?? nativeAsset.symbol,
                required,
                nativeAsset.symbol
            ),
            rechargeButtonTitle: TKLocales.MultichainSwap.Screen.Confirm.BatteryFeeShortage.rechargeBattery,
            depositButtonTitle: TKLocales.Multichain.InsufficientNativeFee.deposit(nativeAsset.symbol)
        )
        PopupContentPresenter.presentBatteryFeeShortage(
            content: content,
            from: viewController,
            onRecharge: onRecharge,
            onDeposit: {
                onDeposit(nativeAsset)
            }
        )
    }

    func presentIfNeeded(
        shortage: MultichainNativeFeeShortage,
        from viewController: UIViewController,
        onDeposit: @escaping (MultichainAssetDetails) -> Void
    ) {
        guard presentationGuard.reservePresentation() else {
            return
        }

        let nativeAsset = shortage.asset
        let walletTitle = InsufficientFeePopupContent.walletTitle(for: wallet)
        let required = amountFormatter.format(
            amount: shortage.requiredAmount,
            fractionDigits: nativeAsset.decimals
        )
        let content = InsufficientFeePopupContent(
            title: TKLocales.Multichain.InsufficientNativeFee.title(
                nativeAsset.symbol,
                nativeAsset.chain?.shortDisplayTitle ?? nativeAsset.symbol,
                walletTitle.argument
            ),
            caption: TKLocales.Multichain.InsufficientNativeFee.caption(
                required,
                nativeAsset.symbol
            ),
            primaryButtonTitle: TKLocales.Multichain.InsufficientNativeFee.deposit(nativeAsset.symbol),
            walletIcon: walletTitle.icon,
            walletName: walletTitle.name,
            walletNamePlaceholder: walletTitle.namePlaceholder
        )
        PopupContentPresenter.presentInsufficientFee(
            content: content,
            from: viewController,
            onPrimary: {
                onDeposit(nativeAsset)
            }
        )
    }
}

final class MultichainNativeFeeShortagePopupPresentationGuard {
    private var isPresentationAvailable = true

    func startNewFeeCalculation() {
        isPresentationAvailable = true
    }

    func reservePresentation() -> Bool {
        guard isPresentationAvailable else {
            return false
        }
        isPresentationAvailable = false
        return true
    }
}
