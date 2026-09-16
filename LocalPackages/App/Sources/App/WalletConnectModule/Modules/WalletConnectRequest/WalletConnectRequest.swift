import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
final class WalletConnectRequest: RouterCoordinator<ViewControllerRouter> {
    var didApprove: ((WalletConnectRequestApprovalState) async throws -> Void)?
    var didReject: (() async throws -> Void)?
    var didDeliverResponse: (() -> Void)?

    private let request: WalletConnectSessionRequest
    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let approvalState = WalletConnectRequestApprovalState()
    private weak var requestViewController: WalletConnectRequestHostingViewController?

    init(
        request: WalletConnectSessionRequest,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: ViewControllerRouter
    ) {
        self.request = request
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    override func start() {
        openRequest()
    }

    func matchesRequest(id: String, topic: String) -> Bool {
        request.id == id
            && request.topic == topic
            && (requestViewController?.matchesRequest(id: id, topic: topic) ?? true)
    }

    func dismissAfterRequestExpired() {
        guard let requestViewController else {
            finish()
            return
        }
        requestViewController.dismissAfterRequestExpired(animated: true) { [weak self] in
            self?.finish()
        }
    }
}

private extension WalletConnectRequest {
    func openRequest() {
        let module = WalletConnectRequestAssembly.module(
            request: request,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        let viewController = module.view
        requestViewController = viewController

        module.output.didReject = { [weak self] in
            guard let self else { return }
            try await self.didReject?()
        }

        module.output.didApprove = { [weak self] in
            guard let self else { return }
            try await self.didApprove?(self.approvalState)
        }

        module.output.didOpenDAppHost = { [weak self] url in
            self?.coreAssembly.urlOpener().open(url: url)
        }

        module.output.didComplete = { [weak self, weak viewController] in
            guard let self else { return }
            let completion = { [weak self] in
                self?.didDeliverResponse?()
                self?.finish()
            }
            guard let viewController,
                  viewController.presentingViewController != nil
            else {
                completion()
                return
            }
            viewController.dismiss(animated: true, completion: completion)
        }

        router.rootViewController.topPresentedViewController().present(viewController, animated: true)
    }

    func finish() {
        didFinish?(self)
    }
}

@MainActor
final class WalletConnectRequestApprovalState {
    private var response: WalletConnectResponseValue?

    func cachedResponse() -> WalletConnectResponseValue? {
        response
    }

    func cacheResponse(_ response: WalletConnectResponseValue) {
        self.response = response
    }
}
