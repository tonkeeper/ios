import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

final class StakingConfirmationCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didClose: (() -> Void)?
    var didRequestOpenDeposit: (() -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?

    private let wallet: Wallet
    private let item: StakingConfirmationItem
    private let initiatedBy: InitiatedBy
    private let utm: UtmParameters
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        wallet: Wallet,
        item: StakingConfirmationItem,
        initiatedBy: InitiatedBy,
        utm: UtmParameters = .empty,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter
    ) {
        self.wallet = wallet
        self.item = item
        self.initiatedBy = initiatedBy
        self.utm = utm
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly

        super.init(router: router)
    }

    override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
        openConfirmation(wallet: wallet, item: item)
    }

    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        guard let walletTransferSignCoordinator = walletTransferSignCoordinator else { return false }
        walletTransferSignCoordinator.externalSignHandler?(sign)
        walletTransferSignCoordinator.externalSignHandler = nil
        return true
    }

    func openConfirmation(wallet: Wallet, item: StakingConfirmationItem) {
        let transactionConfirmationController: TransactionConfirmationController
        switch item.operation {
        case let .deposit(stackingPoolInfo):
            transactionConfirmationController = keeperCoreMainAssembly.stakingDepositTransactionConfirmationController(
                wallet: wallet,
                stakingPool: stackingPoolInfo,
                amount: item.amount,
                isCollect: false
            )
        case let .withdraw(stackingPoolInfo, isCollect):
            transactionConfirmationController = keeperCoreMainAssembly.stakingWithdrawTransactionConfirmationController(
                wallet: wallet,
                stakingPool: stackingPoolInfo,
                amount: item.amount,
                isCollect: isCollect
            )
        }
        let module = TransactionConfirmationAssembly.module(
            transactionConfirmationController: transactionConfirmationController,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            featureFlags: coreAssembly.featureFlags
        )
        var redSession: RedAnalyticsSessionHolder?
        module.output.didRequireSign = { [weak self, keeperCoreMainAssembly, coreAssembly] transferData, wallet throws(WalletTransferSignError) in
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

            self.walletTransferSignCoordinator = coordinator

            return try await coordinator
                .handleSign(parentCoordinator: self)
                .get()
        }

        module.output.didStartConfirmTransaction = { [weak self] _ in
            guard let self else { return }
            let session = RedAnalyticsSessionHolder(
                analytics: coreAssembly.analyticsProvider
            )
            session.start(
                flow: .stake,
                operation: item.operation.redOperation,
                attemptSource: .nativeUI,
                otherMetadata: redMetadata(for: item)
            )
            redSession = session
        }

        module.output.didCancelTransaction = {
            redSession?.finish(
                outcome: .cancel,
                stage: "confirm"
            )
            redSession = nil
        }

        module.output.didConfirmTransaction = { [weak self] model in
            redSession?.finish(
                outcome: .success,
                stage: "send"
            )
            redSession = nil
            guard let self else { return }
            let event = TransactionSent(
                wallet: wallet,
                model: model,
                origin: TransactionOrigin(initiatedBy: initiatedBy, utm: utm)
            )
            if let event {
                self.coreAssembly.analyticsProvider.log(event, utm: self.utm)
            }
            if case .deposit = item.operation {
                self.coreAssembly.analyticsProvider.logStakeCompleted()
            }
        }

        module.output.didFailTransaction = { _, error in
            redSession?.finish(
                outcome: .fail,
                error: error,
                stage: "send"
            )
            redSession = nil
        }

        module.output.didProduceInsufficientFundsError = { [weak self] error in
            guard case let .blockchainFee(_, balance, requiredAmount) = error,
                  case let .withdraw(pool, _) = item.operation
            else { return }
            self?.showInsufficientFundsPopup(
                requiredAmount: requiredAmount,
                reservedAmount: pool.implementation.temporaryReserve,
                balance: balance
            )
        }

        module.output.didClose = { [weak self] in
            self?.didClose?()
        }

        router.push(viewController: module.view, onPopClosures: { [weak self] in
            self?.didFinish?(self)
        })
    }
}

private extension StakingConfirmationCoordinator {
    func showInsufficientFundsPopup(requiredAmount: BigUInt, reservedAmount: BigUInt, balance: BigUInt) {
        let amountFormatter = keeperCoreMainAssembly.formattersAssembly.amountFormatter
        let token = TonToken.ton
        let requiredFormatted = amountFormatter.format(
            amount: requiredAmount,
            fractionDigits: token.fractionDigits,
            accessory: .tokenSymbol(token.symbol)
        )
        let reservedFormatted = amountFormatter.format(
            amount: reservedAmount,
            fractionDigits: token.fractionDigits,
            accessory: .tokenSymbol(token.symbol)
        )
        let balanceFormatted = amountFormatter.format(
            amount: balance,
            fractionDigits: token.fractionDigits,
            accessory: .tokenSymbol(token.symbol)
        )

        var depositButton = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        depositButton.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.InsufficientFunds.depositWallet)
        )
        depositButton.action = { [weak self] in
            self?.router.dismiss(animated: true) {
                self?.didRequestOpenDeposit?()
            }
        }

        let configuration = InfoPopupBottomSheetConfigurationBuilder(amountFormatter: amountFormatter)
            .insufficientTokenConfiguration(
                walletLabel: nil,
                caption: TKLocales.InsufficientFunds.actionRequired(requiredFormatted, balanceFormatted),
                footnote: TKLocales.InsufficientFunds.unstakeReserved(reservedFormatted),
                tokenSymbol: token.symbol,
                tokenFractionalDigits: token.fractionDigits,
                required: requiredAmount,
                available: balance,
                buttons: [depositButton]
            )

        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
        viewController.configuration = configuration
        bottomSheetViewController.present(fromViewController: router.rootViewController)
    }

    func redMetadata(for item: StakingConfirmationItem) -> RedAnalyticsMetadata {
        let pool: StackingPoolInfo
        switch item.operation {
        case let .deposit(stackingPoolInfo):
            pool = stackingPoolInfo
        case let .withdraw(stackingPoolInfo, _):
            pool = stackingPoolInfo
        }
        return [
            .amount: NSDecimalNumber.fromBigUInt(
                value: item.amount,
                decimals: TonInfo.fractionDigits
            ).doubleValue,
            .poolAddress: pool.address.toRaw(),
            .poolKind: pool.implementation.type.rawValue,
        ]
    }
}

private extension StakingConfirmationItem.Operation {
    var redOperation: OpAttempt.Operation {
        switch self {
        case .deposit:
            return .stake
        case .withdraw:
            return .unstake
        }
    }
}
