import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TKLocalize
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

public final class WebSwapCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didClose: (() -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?

    private let wallet: Wallet
    private let fromToken: String?
    private let toToken: String?
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    public init(
        wallet: Wallet,
        fromToken: String?,
        toToken: String?,
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.wallet = wallet
        self.fromToken = fromToken
        self.toToken = toToken
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        super.init(router: router)
    }

    override public func start() {
        openSwap()
    }

    public func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        guard let walletTransferSignCoordinator else { return false }

        walletTransferSignCoordinator.externalSignHandler?(sign)
        walletTransferSignCoordinator.externalSignHandler = nil

        return true
    }
}

private extension WebSwapCoordinator {
    func openSwap() {
        let messageHandler = DefaultStonfiSwapMessageHandler()
        let module = StonfiSwapAssembly.module(
            wallet: wallet,
            fromToken: fromToken,
            toToken: toToken,
            keeperCoreAssembly: keeperCoreMainAssembly,
            messageHandler: messageHandler
        )

        messageHandler.send = { [weak self] request, completion in
            self?.openSend(signRequest: request, completion: completion)
        }

        messageHandler.close = {
            [weak self] in
            guard let self else { return }
            self.didClose?()
        }

        module.view.overrideUserInterfaceStyle = .dark
        module.view.modalPresentationStyle = .fullScreen
        router.push(viewController: module.view)
    }

    func openSend(
        signRequest: SignRawRequest,
        completion: @escaping (SendTransactionSignResult) -> Void
    ) {
        guard let windowScene = router.rootViewController.windowScene else { return }
        SignRawPresenter.presentSignRaw(
            windowScene: windowScene,
            windowLevel: .signRaw,
            wallet: wallet,
            transferProvider: { .stonfiSwap(signRequest) },
            resultHandler: ResultHandler(completion: completion),
            sendFrom: .tonconnectRemote,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            didRequireSign: { [weak self] transferData, wallet, coordinator, router throws(WalletTransferSignError) in
                guard let self else {
                    throw .cancelled
                }
                return try await didRequireSign(
                    transferData: transferData,
                    wallet: wallet,
                    coordinator: coordinator,
                    router: router
                )
            }
        )
    }

    @MainActor
    func didRequireSign(
        transferData: TransferData,
        wallet: Wallet,
        coordinator: Coordinator,
        router: ViewControllerRouter
    ) async throws(WalletTransferSignError) -> SignedTransactions {
        let signCoordinator = WalletTransferSignCoordinator(
            router: router,
            wallet: wallet,
            transferData: transferData,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        self.walletTransferSignCoordinator = signCoordinator

        return try await signCoordinator
            .handleSign(parentCoordinator: coordinator)
            .get()
    }
}

private struct ResultHandler: SignRawControllerResultHandler {
    private let completion: (SendTransactionSignResult) -> Void

    init(completion: @escaping (SendTransactionSignResult) -> Void) {
        self.completion = completion
    }

    func didConfirm(boc: String) {
        completion(.response(boc))
    }

    func didFail(error: SomeOf<TransferError, TransactionConfirmationError>) {
        completion(.error(.unknownError))
    }

    func didCancel() {
        completion(.error(.userDeclinedAction))
    }
}
