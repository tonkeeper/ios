import KeeperCore
import TKCoordinator
import TKCore
import TKLogging
import TKUIKit
import UIKit

final class ImportWatchOnlyWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didCancel: (() -> Void)?
    var didImportWallet: (() -> Void)?

    private let walletsUpdateAssembly: WalletsUpdateAssembly
    private let multichainAssembly: MultichainAssembly
    private let analyticsProvider: AnalyticsProvider
    private let customizeWalletModule: (_ name: String?) -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    private let analyticsContext: WalletFlowAnalyticsContext

    init(
        router: NavigationControllerRouter,
        analyticsProvider: AnalyticsProvider,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        multichainAssembly: MultichainAssembly,
        analyticsContext: WalletFlowAnalyticsContext,
        customizeWalletModule: @escaping (_ name: String?) -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    ) {
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.multichainAssembly = multichainAssembly
        self.customizeWalletModule = customizeWalletModule
        self.analyticsProvider = analyticsProvider
        self.analyticsContext = analyticsContext
        super.init(router: router)
    }

    override func start() {
        openWatchOnlyWalletAddressInput()
    }
}

private extension ImportWatchOnlyWalletCoordinator {
    func openWatchOnlyWalletAddressInput() {
        let module = WatchOnlyWalletAddressInputAssembly.module(controller: walletsUpdateAssembly.watchOnlyWalletAddressInputController())

        module.output.didInputWallet = { [weak self] resolvableAddress in
            self?.openNotifications(resolvableAddress: resolvableAddress)
        }

        if router.rootViewController.viewControllers.isEmpty {
            module.view.setupSwipeDownButton { [weak self] in
                self?.didCancel?()
            }
        } else {
            module.view.setupBackButton()
        }

        router.push(viewController: module.view, onPopClosures: { [weak self] in
            self?.didCancel?()
        })
    }

    func openNotifications(resolvableAddress: ResolvableAddress) {
        OnboardingNotificationsStep.push(router: router) { [weak self] in
            self?.openCustomizeWallet(resolvableAddress: resolvableAddress)
        }
    }

    func openCustomizeWallet(resolvableAddress: ResolvableAddress) {
        let name: String?
        switch resolvableAddress {
        case let .Domain(domain, _):
            name = domain
        case .Resolved:
            name = nil
        }
        let module = customizeWalletModule(name)

        module.output.didCustomizeWallet = { [weak self] model in
            guard let self else { return }
            Task {
                await self.importWallet(
                    resolvableAddress: resolvableAddress,
                    model: model
                )
            }
        }

        if router.rootViewController.viewControllers.isEmpty {
            module.view.setupHeaderLeftCloseButton { [weak self] in
                self?.didCancel?()
            }
        } else {
            module.view.setupHeaderBackButton()
        }

        router.push(viewController: module.view)
    }

    func importWallet(
        resolvableAddress: ResolvableAddress,
        model: CustomizeWalletModel
    ) async {
        let addController = walletsUpdateAssembly.walletAddController(
            multichainAssembly: multichainAssembly
        )
        let metaData = WalletMetaData(
            label: model.name,
            tintColor: model.tintColor,
            icon: model.icon
        )
        do {
            try await addController.importWatchOnlyWallet(
                resolvableAddress: resolvableAddress,
                metaData: metaData
            )
            analyticsProvider.logWalletImportSuccess(
                walletMode: .single,
                walletSource: .watchonly,
                from: analyticsContext.from
            )
            await MainActor.run {
                didImportWallet?()
            }
        } catch {
            Log.e("Watch only wallet import failed", extraInfo: [
                "error": error.localizedDescription,
            ])
            analyticsProvider.logWalletImportError(
                walletMode: .single,
                walletSource: .watchonly,
                from: analyticsContext.from,
                error: error
            )
        }
    }
}
