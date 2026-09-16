import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
final class LegacyReceiveCoordinator<V: UIViewController>: RouterCoordinator<ContainerViewControllerRouter<V>>, ReceiveCoordinator {
    var didClose: (() -> Void)?

    private let tokens: [ReceiveLegacyToken]
    private let initialToken: ReceiveLegacyToken?
    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let didDisplayToken: ((Token) -> Void)?

    init(
        router: ContainerViewControllerRouter<V>,
        tokens: [ReceiveLegacyToken],
        initialToken: ReceiveLegacyToken? = nil,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        didDisplayToken: ((Token) -> Void)?
    ) {
        self.tokens = tokens
        self.initialToken = initialToken
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.didDisplayToken = didDisplayToken
        super.init(router: router)
    }

    override func start() {
        let module = module(tokens: tokens, wallet: wallet)
        let navigationController = TKNavigationController(
            rootViewController: module.view
        )
        navigationController.setNavigationBarHidden(true, animated: false)
        router.presentOverTopPresented(
            navigationController,
            onDismiss: { [weak self] in
                self?.didClose?()
            }
        )
    }
}

extension LegacyReceiveCoordinator {
    private func module(
        tokens: [ReceiveLegacyToken],
        wallet: Wallet
    ) -> MVVMModule<UIViewController, ReceiveModuleOutput, ReceiveModuleInput> {
        let keeperCoreMainAssembly = keeperCoreMainAssembly
        let viewModel = ReceiveLegacyViewModelImplementation(
            tokens: tokens,
            initialToken: initialToken,
            tokenModuleViewControllerProvider: { receiveItem in
                ReceiveTabAssembly.module(
                    token: receiveItem,
                    wallet: wallet,
                    qrCodeGenerator: keeperCoreMainAssembly.coreAssembly
                        .qrCodeGenerator(persistent: true),
                    keeperCoreAssembly: keeperCoreMainAssembly
                ).view
            }
        )
        let didDisplayToken = self.didDisplayToken
        viewModel.didDisplayToken = { token in
            didDisplayToken?(token.token)
        }
        viewModel.didRequestClose = { [weak self, router] in
            router.dismiss(completion: self?.didClose)
        }
        let viewController = ReceiveLegacyViewController(viewModel: viewModel)
        return MVVMModule(
            view: viewController,
            output: viewModel,
            input: viewModel
        )
    }
}
