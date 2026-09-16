import KeeperCore
import SafariServices
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import TronSwift
import UIKit

enum TopUpReason {
    case insufficient
    case topup
}

final class TopUpCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private let wallet: Wallet
    private let snapshot: TronUsdtFeesSnapshot
    private let reason: TopUpReason
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    var openBattery: (() -> Void)?

    init(
        wallet: Wallet,
        reason: TopUpReason,
        snapshot: TronUsdtFeesSnapshot,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter
    ) {
        self.wallet = wallet
        self.reason = reason
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.snapshot = snapshot
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    override func start() {
        openFeeOptions(
            wallet: wallet,
            snapshot: snapshot,
            isInsufficientMode: reason == .insufficient
        )
    }
}

// MARK: - Fee Options

extension TopUpCoordinator {
    private func openFeeOptions(
        wallet: Wallet,
        snapshot: TronUsdtFeesSnapshot,
        isInsufficientMode: Bool
    ) {
        Log.tron.i(
            "Opened Fee Options popup",
            extraInfo: [
                "mode": isInsufficientMode ? "insufficient" : "normal",
                "batteryChargesBalance": String(snapshot.batteryChargesBalance),
                "requiredBatteryCharges": String(snapshot.requiredBatteryCharges),
                "tonBalanceNano": snapshot.tonBalance.description,
                "requiredTONNano": snapshot.requiredTON.description,
                "trxBalance": snapshot.trxBalance.description,
                "requiredTRX": String(snapshot.requiredTRX),
            ]
        )

        let title = if isInsufficientMode {
            TKLocales.TronUsdtFees.Common.FeeOptions.Title.insufficient
        } else {
            if snapshot.isTRXOnlyRegion {
                TKLocales.TronUsdtFees.TrxBalancePopup.title
            } else {
                TKLocales.TronUsdtFees.Common.FeeOptions.Title.default
            }
        }
        let caption = if isInsufficientMode {
            TKLocales.TronUsdtFees.Common.FeeOptions.Caption.insufficient
        } else {
            if snapshot.isTRXOnlyRegion {
                TKLocales.TronUsdtFees.TrxBalancePopup.caption
            } else {
                TKLocales.TronUsdtFees.Common.FeeOptions.Caption.default
            }
        }

        let requiredTon = keeperCoreMainAssembly.formattersAssembly.amountFormatter.format(
            amount: snapshot.requiredTON,
            fractionDigits: TonInfo.fractionDigits,
            accessory: .tokenSymbol(TonInfo.symbol)
        )
        let tonBalance = keeperCoreMainAssembly.formattersAssembly.amountFormatter.format(
            amount: snapshot.tonBalance,
            fractionDigits: TonInfo.fractionDigits,
            accessory: .tokenSymbol(TonInfo.symbol)
        )
        let trxBalance = keeperCoreMainAssembly.formattersAssembly.amountFormatter.format(
            amount: snapshot.trxBalance,
            fractionDigits: TRX.fractionDigits,
            accessory: .tokenSymbol(TRX.symbol)
        )
        let requiredTrx = keeperCoreMainAssembly.formattersAssembly.amountFormatter.format(
            amount: snapshot.requiredTRX,
            fractionDigits: TRX.fractionDigits,
            accessory: .tokenSymbol(TRX.symbol)
        )

        let batteryRequired = "\(snapshot.requiredBatteryCharges) \(TKLocales.Battery.Refill.chargesCount(count: snapshot.requiredBatteryCharges))"
        let batteryBalance = "\(snapshot.batteryChargesBalance) \(TKLocales.Battery.Refill.chargesCount(count: snapshot.batteryChargesBalance))"

        let batteryItem = makeFeeOptionItem(
            title: TKLocales.TronUsdtFees.Common.ItemTitle.battery,
            icon: .battery(fillPercent: snapshot.batteryFillPercent),
            caption: TKLocales.TronUsdtFees.Common.ItemCaption.balanceRequired(
                batteryBalance,
                batteryRequired
            ),
            action: { [weak self] in
                self?.openBattery?()
            }
        )

        let tonItem = makeFeeOptionItem(
            title: TKLocales.TronUsdtFees.Common.ItemTitle.ton,
            icon: .ton,
            caption: TKLocales.TronUsdtFees.Common.ItemCaption.balanceRequired(
                tonBalance,
                requiredTon
            ),
            action: { [weak self] in
                self?.openReceive(token: .ton(.ton))
            }
        )

        let trxItem = makeFeeOptionItem(
            title: TKLocales.TronUsdtFees.Common.ItemTitle.trx,
            icon: .trx,
            caption: snapshot.isTRXOnlyRegion ? TKLocales.TronUsdtFees.TrxBalancePopup.itemCaption(
                trxBalance,
                snapshot.trxTransfersAvailable,
                requiredTrx
            ) : TKLocales.TronUsdtFees.Common.ItemCaption.balanceRequired(
                trxBalance,
                requiredTrx
            ),
            action: { [weak self] in
                self?.openReceive(token: .tron(.trx))
            }
        )

        let popupViewController = TKPopUp.ViewController(
            configuration: TKPopUp.Configuration(
                items: [
                    TKPopUp.Component.TitleCaption(
                        title: title,
                        caption: caption,
                        bottomSpace: 16
                    ),
                    TKPopUp.Component.List(
                        configuration: TKListContainerView.Configuration(
                            items: snapshot.isTRXOnlyRegion ? [
                                trxItem,
                            ] : [
                                batteryItem,
                                tonItem,
                                trxItem,
                            ],
                            copyToastConfiguration: wallet.copyToastConfiguration(),
                            horizontalPadding: 16
                        ),
                        bottomSpace: 16
                    ),
                    TronUSDTFeeDisclaimerItem(
                        text: makeTronUSDTFeeDisclaimerText(),
                        actionText: TKLocales.TronUsdtFees.Common.Links.learnMore,
                        action: { [weak self] in
                            self?.openHelpCenter()
                        },
                        horizontalPadding: 16,
                        bottomSpace: 16
                    ),
                ]
            )
        )
        popupViewController.headerConfiguration = TKBottomSheetHeaderConfiguration(
            title: .empty,
            contentInsets: UIEdgeInsets(
                top: 16,
                left: 16,
                bottom: 0,
                right: 16
            )
        )
        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: popupViewController
        )

        bottomSheetViewController.present(
            fromViewController: router.rootViewController
        )
    }

    func makeFeeOptionItem(
        title: String,
        icon: TronUSDTFeeOptionIcon,
        caption: String,
        action: @escaping () -> Void
    ) -> TKListContainerItem {
        TronUSDTFeeOptionListItem(
            title: title,
            icon: icon,
            caption: caption,
            action: action
        )
    }

    func makeTronUSDTFeeDisclaimerText() -> NSAttributedString {
        let text = NSMutableAttributedString(
            attributedString: TKLocales.TronUsdtFees.Common.disclaimer.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
        )
        text.append(" \(TKLocales.TronUsdtFees.Common.Links.learnMore)".withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        ))
        return text
    }

    func openHelpCenter() {
        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
        guard let url = configuration.multichainHelpUrl else {
            return
        }
        let viewController = SFSafariViewController(url: url)
        router.rootViewController.topPresentedViewController().present(viewController, animated: true)
    }
}

// MARK: - Receive

extension TopUpCoordinator {
    private func openReceive(token: Token) {
        guard let coordinator = ReceiveModule(
            dependencies: .init(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        .createReceiveCoordinator(
            router: router,
            token: token,
            wallet: wallet
        ) else {
            return
        }

        coordinator.didClose = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
        }

        addChild(coordinator)
        coordinator.start()
    }
}
