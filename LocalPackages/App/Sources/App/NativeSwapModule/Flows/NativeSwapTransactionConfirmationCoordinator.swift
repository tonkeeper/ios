import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

final class NativeSwapTransactionConfirmationCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didClose: (() -> Void)?
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)?
    var didTapEdit: ((Bool?) -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?

    private let wallet: Wallet
    private let model: NativeSwapTransactionConfirmationModel
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        wallet: Wallet,
        model: NativeSwapTransactionConfirmationModel,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter
    ) {
        self.wallet = wallet
        self.model = model
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly

        super.init(router: router)
    }

    override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
        openConfirmation()
    }

    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        guard let walletTransferSignCoordinator else { return false }

        walletTransferSignCoordinator.externalSignHandler?(sign)
        walletTransferSignCoordinator.externalSignHandler = nil

        return true
    }

    func cancelPendingSignerFlow() {
        walletTransferSignCoordinator?.externalSignHandler?(nil)
        walletTransferSignCoordinator?.externalSignHandler = nil
    }

    func openConfirmation() {
        let transactionConfirmationController = keeperCoreMainAssembly.nativeSwapTransactionConfirmationController(
            wallet: wallet,
            confirmation: model.confirmation,
            fromToken: model.fromToken,
            toToken: model.toToken,
            fromAmount: model.fromAmount,
            transferService: keeperCoreMainAssembly.transferAssembly.transferService(),
            tonConnectService: keeperCoreMainAssembly.tonConnectAssembly.tonConnectService(),
            balanceService: keeperCoreMainAssembly.servicesAssembly.balanceService(),
            settingsRepository: keeperCoreMainAssembly.repositoriesAssembly.settingsRepository(),
            batteryCalculation: keeperCoreMainAssembly.batteryAssembly.batteryCalculation
        )

        let module = NativeSwapTransactionConfirmationAssembly.module(
            wallet: wallet,
            model: model,
            transactionConfirmationController: transactionConfirmationController,
            keeperCoreAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        module.output.didRequireSign = { [weak self] transferData, wallet throws(WalletTransferSignError) in
            guard let self else {
                throw .cancelled
            }

            let coordinator = WalletTransferSignCoordinator(
                router: ViewControllerRouter(rootViewController: router.rootViewController),
                wallet: wallet,
                transferData: transferData,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )

            walletTransferSignCoordinator = coordinator

            return try await coordinator
                .handleSign(parentCoordinator: self)
                .get()
        }

        module.output.didConfirmTransaction = { [weak self] in
            self?.didClose?()
        }

        module.output.didClose = { [weak self] in
            self?.didClose?()
        }

        module.output.didTapEdit = { [weak self] isSend in
            self?.didTapEdit?(isSend)
        }

        module.output.didProduceInsufficientFundsError = { [weak self] error in
            guard let self else { return }

            let symbol: String
            let fractionDigits: Int
            let buttonTitle: String
            let caption: String?
            let amount: BigUInt
            let availableBalance: BigUInt
            let internalPurchasingFlow: Bool

            switch error {
            case .unknownJetton:
                ToastPresenter.showToast(configuration: .failed)
                return
            case let .blockchainFee(_, balance, requiredAmount):
                let tonToken = TonToken.ton
                let token = TonToken.ton
                symbol = token.symbol
                fractionDigits = token.fractionDigits
                amount = requiredAmount
                availableBalance = balance

                let amountFormatter = keeperCoreMainAssembly.formattersAssembly.amountFormatter
                let feeFormatted = amountFormatter.format(
                    amount: amount,
                    fractionDigits: tonToken.fractionDigits
                )
                let balanceFormatted = amountFormatter.format(
                    amount: balance,
                    fractionDigits: tonToken.fractionDigits
                )
                caption = TKLocales.InsufficientFunds.feeRequired(feeFormatted, balanceFormatted)
                buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(tonToken.symbol)

                internalPurchasingFlow = true
            case let .insufficientFunds(jettonInfo, balance, requiredAmount, _, isInternalPurchasing):
                caption = nil
                amount = requiredAmount
                availableBalance = balance

                if let jettonInfo {
                    fractionDigits = jettonInfo.fractionDigits
                    symbol = jettonInfo.symbol ?? jettonInfo.name
                    buttonTitle = TKLocales.InsufficientFunds.rechargeWallet
                } else {
                    fractionDigits = TonToken.ton.fractionDigits
                    symbol = TonToken.ton.symbol
                    buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(symbol)
                }

                internalPurchasingFlow = isInternalPurchasing
            }

            configureAndShowInsufficientPopup(
                caption: caption,
                buttonTitle: buttonTitle,
                amount: amount,
                tokenSymbol: symbol,
                fractionDigits: fractionDigits,
                balance: availableBalance,
                isInternalPurchasing: internalPurchasingFlow
            )
        }

        router.push(viewController: module.view)
    }

    func configureAndShowInsufficientPopup(
        caption: String? = nil,
        buttonTitle: String,
        amount: BigUInt?,
        tokenSymbol: String?,
        fractionDigits: Int,
        balance: BigUInt,
        isInternalPurchasing: Bool
    ) {
        var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .secondary,
            size: .large
        )
        buyButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(buttonTitle)
        )
        buyButtonConfiguration.action = { [weak self] in
            guard let self else { return }

            didRequestOpenBuySell?(isInternalPurchasing)
        }

        let builder = InfoPopupBottomSheetConfigurationBuilder(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        let configuration = builder.insufficientTokenConfiguration(
            walletLabel: wallet.metaData.label,
            caption: caption,
            tokenSymbol: tokenSymbol ?? TonToken.ton.symbol,
            tokenFractionalDigits: fractionDigits,
            required: amount ?? 0,
            available: balance,
            buttons: [buyButtonConfiguration]
        )

        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
        viewController.configuration = configuration
        bottomSheetViewController.present(fromViewController: router.rootViewController)
    }
}
