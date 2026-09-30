import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

public final class CollectiblesCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private enum PresentationStyle: Equatable {
        case root
        case pushed
    }

    var didOpenDapp: ((_ url: URL, _ title: String?) -> Void)?
    var didRequestDeeplinkHandling: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool, _ wallet: Wallet) -> Void)?
    var didRequestDepositTon: ((_ wallet: Wallet) -> Void)?

    private weak var detailsCoordinator: CollectiblesDetailsCoordinator?
    private var presentationStyle: PresentationStyle = .root

    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    public init(
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        configuresTabBarItem: Bool = true
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        super.init(router: router)
        if configuresTabBarItem {
            router.rootViewController.tabBarItem.title = TKLocales.Tabs.collectibles
            router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.purchase
        }
    }

    override public func start() {
        presentationStyle = .root
        openCollectibles(
            onBack: nil,
            animated: false,
            onPop: nil
        )
    }

    public func push(
        onBack: @escaping () -> Void,
        onPop: (() -> Void)? = nil
    ) {
        presentationStyle = .pushed
        openCollectibles(
            onBack: onBack,
            animated: true,
            onPop: onPop
        )
    }

    public func handleTonkeeperDeeplink(deeplink: Deeplink) -> Bool {
        if let detailsCoordinator = detailsCoordinator {
            return detailsCoordinator.handleTonkeeperDeeplink(deeplink: deeplink)
        }
        return false
    }
}

private extension CollectiblesCoordinator {
    func openCollectibles(
        onBack: (() -> Void)?,
        animated: Bool,
        onPop: (() -> Void)?
    ) {
        let module = CollectiblesContainerAssembly.module(keeperCoreMainAssembly: keeperCoreMainAssembly)

        module.output.didChangeWallet = { [weak self, keeperCoreMainAssembly] wallet in
            let listModule = CollectiblesListAssembly.module(
                wallet: wallet,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )

            listModule.output.didSelectNFT = { nft, wallet in
                self?.openNFTDetails(wallet: wallet, nft: nft)
            }

            listModule.output.didRequestOpenTonCollectiblesPopup = { [weak self] in
                guard let self else { return }
                PopupContentPresenter.presentTonCollectibles(
                    from: self.router.rootViewController.topPresentedViewController()
                )
            }

            listModule.output.didTapCollectiblesSettings = { [weak self] isSpam in
                guard let self else {
                    return
                }
                self.openPurchases(wallet: wallet, isSpam: isSpam)
            }

            listModule.view.configureHeader(onTapBack: onBack)
            module.view.collectiblesViewController = listModule.view
        }
        router.push(
            viewController: module.view,
            animated: animated,
            onPopClosures: onPop
        )
    }

    func openNFTDetails(wallet: Wallet, nft: NFT) {
        guard let wallet = keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: wallet.id) else { return }

        if presentationStyle == .pushed {
            openPushedNFTDetails(wallet: wallet, nft: nft)
            return
        }

        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = CollectiblesDetailsCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            nft: nft,
            wallet: wallet,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didOpenDapp = { [weak self] url, title in
            self?.didOpenDapp?(url, title)
        }

        coordinator.didPerformTransaction = { [weak self, weak coordinator] in
            self?.didFinish?(coordinator)
        }

        coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
            navigationController?.dismiss(animated: true)
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didRequestDeeplinkHandling = { [weak self] deeplink, utm in
            self?.didRequestDeeplinkHandling?(deeplink, utm)
        }

        coordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            self?.didRequestOpenBuySell?(isInternalPurchasing, wallet)
        }

        coordinator.didRequestDepositTon = { [weak self] in
            self?.didRequestDepositTon?(wallet)
        }

        self.detailsCoordinator = coordinator

        coordinator.start()
        addChild(coordinator)

        router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        })
    }

    func openPushedNFTDetails(wallet: Wallet, nft: NFT) {
        let coordinator = CollectiblesDetailsCoordinator(
            router: router,
            nft: nft,
            wallet: wallet,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            presentationStyle: .pushed
        )

        coordinator.didOpenDapp = { [weak self] url, title in
            self?.didOpenDapp?(url, title)
        }

        coordinator.didClose = { [weak self, weak coordinator] in
            guard let self, let coordinator else { return }
            self.removeChild(coordinator)
            if self.detailsCoordinator === coordinator {
                self.detailsCoordinator = nil
            }
        }

        coordinator.didRequestDeeplinkHandling = { [weak self] deeplink, utm in
            self?.didRequestDeeplinkHandling?(deeplink, utm)
        }

        coordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            self?.didRequestOpenBuySell?(isInternalPurchasing, wallet)
        }

        coordinator.didRequestDepositTon = { [weak self] in
            self?.didRequestDepositTon?(wallet)
        }

        self.detailsCoordinator = coordinator

        coordinator.start()
        addChild(coordinator)
    }

    func openPurchases(wallet: Wallet, isSpam: Bool) {
        guard let wallet = keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: wallet.id) else { return }
        let module = SettingsPurchasesAssembly.module(
            wallet: wallet,
            mode: isSpam ? .spam : .all,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        module.output.didOpenTonviewer = { [weak self] url in
            self?.didOpenDapp?(url, "Tonviewer")
        }

        router.rootViewController.setNavigationBarHidden(true, animated: false)

        router.push(viewController: module.view)
    }
}
