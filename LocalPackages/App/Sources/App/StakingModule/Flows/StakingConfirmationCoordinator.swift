import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

final class StakingConfirmationCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didClose: (() -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?

    private let wallet: Wallet
    private let item: StakingConfirmationItem
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        wallet: Wallet,
        item: StakingConfirmationItem,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter
    ) {
        self.wallet = wallet
        self.item = item
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
        case let .withdraw(stackingPoolInfo):
            transactionConfirmationController = keeperCoreMainAssembly.stakingWithdrawTransactionConfirmationController(
                wallet: wallet,
                stakingPool: stackingPoolInfo,
                amount: item.amount,
                isCollect: false
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
                analytics: coreAssembly.analyticsProvider,
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
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

        module.output.didConfirmTransaction = { _ in
            redSession?.finish(
                outcome: .success,
                stage: "send"
            )
            redSession = nil
        }

        module.output.didFailTransaction = { _, error in
            redSession?.finish(
                outcome: .fail,
                error: error,
                stage: "send"
            )
            redSession = nil
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
    func redMetadata(for item: StakingConfirmationItem) -> RedAnalyticsMetadata {
        let pool: StackingPoolInfo
        switch item.operation {
        case let .deposit(stackingPoolInfo):
            pool = stackingPoolInfo
        case let .withdraw(stackingPoolInfo):
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
