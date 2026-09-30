import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit
import UIKit

public final class WalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didTapScan: (() -> Void)?
    var didTapWalletButton: (() -> Void)?
    var didTapSend: ((Wallet) -> Void)?
    var didTapWithdraw: ((Wallet) -> Void)?
    var didTapDeposit: ((Wallet) -> Void)?
    var didTapSwap: ((Wallet) -> Void)?
    var didTapStake: ((Wallet) -> Void)?
    var didTapSettingsButton: ((Wallet) -> Void)?
    var didTapHistoryButton: (() -> Void)?
    var didSelectTonDetails: ((Wallet) -> Void)?
    var didSelectJettonDetails: ((Wallet, JettonItem, Bool) -> Void)?
    var didSelectTronUSDTDetails: ((Wallet) -> Void)?
    var didSelectTronTRXDetails: ((Wallet) -> Void)?
    var didSelectEthenaDetails: ((Wallet) -> Void)?
    var didSelectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?
    var didSelectCollectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?
    var didTapBackup: ((Wallet) -> Void)?
    var didTapBattery: ((Wallet) -> Void)?
    var didRequestDeeplinkHandling: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    var didRequestBannerDeeplinkHandling: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    var didTapOpenCryptoAssets: (() -> Void)?
    var collectiblesDidOpenDapp: ((_ url: URL, _ title: String?) -> Void)?
    var collectiblesDidRequestOpenBuySell: ((_ isInternalPurchasing: Bool, _ wallet: Wallet) -> Void)?
    var collectiblesDidRequestDepositTon: ((_ wallet: Wallet) -> Void)?

    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let collectiblesModule: CollectiblesModule
    private weak var walletContainerViewController: WalletContainerViewController?
    private weak var collectiblesCoordinator: CollectiblesCoordinator?
    private weak var collectiblesDetailsCoordinator: CollectiblesDetailsCoordinator?

    func historyButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void) {
        walletContainerViewController?.historyButtonTooltipSourceView(completion)
    }

    func walletButtonTooltipSourceView(_ completion: @escaping (UIView) -> Void) {
        walletContainerViewController?.walletButtonTooltipSourceView(completion)
    }

    init(
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.collectiblesModule = CollectiblesModule(
            dependencies: CollectiblesModule.Dependencies(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        )
        super.init(router: router)
        router.rootViewController.tabBarItem.title = TKLocales.Tabs.wallet
        router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.wallet
    }

    override public func start() {
        openWalletContainer()
    }

    public func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        let deeplink = Deeplink.publish(sign: sign)
        if let collectiblesDetailsCoordinator,
           collectiblesDetailsCoordinator.handleTonkeeperDeeplink(deeplink: deeplink)
        {
            return true
        }
        if let collectiblesCoordinator,
           collectiblesCoordinator.handleTonkeeperDeeplink(deeplink: deeplink)
        {
            return true
        }
        return false
    }
}

private extension WalletCoordinator {
    func openWalletContainer() {
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else {
            return
        }
        let module = WalletContainerAssembly.module(
            walletBalanceModule: createWalletBalanceModule(wallet: wallet),
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore
        )
        walletContainerViewController = module.view

        module.output.walletButtonHandler = { [weak self] in
            self?.didTapWalletButton?()
        }

        module.output.didTapScan = { [weak self] in
            self?.didTapScan?()
        }

        module.output.didTapSettingsButton = { [weak self] wallet in
            self?.didTapSettingsButton?(wallet)
        }

        module.output.didTapHistoryButton = { [weak self] in
            self?.didTapHistoryButton?()
        }

        router.push(viewController: module.view, animated: false)
    }

    func openManageTokens(wallet: Wallet) {
        let coordinator = ManageTokensCoordinator(
            router: router,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
            visibilityChangesController: keeperCoreMainAssembly.visibilityChangesController
        )
        addChild(coordinator)
        coordinator.didFinish = { [weak self, weak coordinator] _ in
            self?.removeChild(coordinator)
        }

        coordinator.start()
    }

    @MainActor
    func createWalletBalanceModule(wallet: Wallet) -> WalletBalanceModule {
        let module = WalletBalanceAssembly.module(
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        module.output.didSelectTon = { [weak self] wallet in
            self?.didSelectTonDetails?(wallet)
        }

        module.output.didSelectJetton = { [weak self] wallet, jettonItem, hasPrice in
            self?.didSelectJettonDetails?(wallet, jettonItem, hasPrice)
        }

        module.output.didSelectTronUSDT = { [weak self] wallet in
            self?.didSelectTronUSDTDetails?(wallet)
        }

        module.output.didSelectTronTRX = { [weak self] wallet in
            self?.didSelectTronTRXDetails?(wallet)
        }

        module.output.didSelectEthena = { [weak self] wallet in
            self?.didSelectEthenaDetails?(wallet)
        }

        module.output.didSelectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStackingInfo in
            self?.didSelectStakingItem?(wallet, stakingPoolInfo, accountStackingInfo)
        }

        module.output.didSelectCollectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStackingInfo in
            self?.didSelectCollectStakingItem?(wallet, stakingPoolInfo, accountStackingInfo)
        }

        module.output.didTapWithdraw = { [weak self] wallet in
            self?.didTapWithdraw?(wallet)
        }

        module.output.didTapDeposit = { [weak self] wallet in
            self?.didTapDeposit?(wallet)
        }

        module.output.didTapSwap = { [weak self] wallet in
            self?.didTapSwap?(wallet)
        }

        module.output.didTapStake = { [weak self] wallet in
            self?.didTapStake?(wallet)
        }

        module.output.didTapBackup = { [weak self] wallet in
            self?.didTapBackup?(wallet)
        }

        module.output.didTapBattery = { [weak self] wallet in
            self?.didTapBattery?(wallet)
        }

        module.output.didTapManage = { [weak self] wallet in
            self?.openManageTokens(wallet: wallet)
        }

        module.output.didTapOpenCryptoAssets = { [weak self] in
            self?.didTapOpenCryptoAssets?()
        }

        module.output.didRequirePasscode = { [weak self] in
            await self?.getPasscode()
        }

        module.output.didTapOpenCollectibles = { [weak self] in
            self?.openCollectibles()
        }
        module.output.didSelectNFT = { [weak self] wallet, nft in
            self?.openNFTDetails(wallet: wallet, nft: nft)
        }

        module.output.didRequestBannerDeeplinkHandling = { [weak self] deeplink, utm in
            self?.didRequestBannerDeeplinkHandling?(deeplink, utm)
        }

        return module
    }

    func openCollectibles() {
        guard collectiblesCoordinator == nil else { return }
        let navigationController = router.rootViewController.tabBarHostNavigationController
        let collectiblesCoordinator = collectiblesModule.createCollectiblesCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            configuresTabBarItem: false
        )
        collectiblesCoordinator.didOpenDapp = { [weak self] url, title in
            self?.collectiblesDidOpenDapp?(url, title)
        }
        collectiblesCoordinator.didRequestDeeplinkHandling = { [weak self] deeplink, utm in
            self?.didRequestDeeplinkHandling?(deeplink, utm)
        }
        collectiblesCoordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing, wallet in
            self?.collectiblesDidRequestOpenBuySell?(isInternalPurchasing, wallet)
        }
        collectiblesCoordinator.didRequestDepositTon = { [weak self] wallet in
            self?.collectiblesDidRequestDepositTon?(wallet)
        }

        self.collectiblesCoordinator = collectiblesCoordinator

        let removeCollectibles = { [weak self, weak collectiblesCoordinator] in
            guard let self, let collectiblesCoordinator else { return }
            self.removeChild(collectiblesCoordinator)
            if self.collectiblesCoordinator === collectiblesCoordinator {
                self.collectiblesCoordinator = nil
            }
        }

        collectiblesCoordinator.didFinish = { _ in
            removeCollectibles()
        }

        addChild(collectiblesCoordinator)
        collectiblesCoordinator.push(
            onBack: { [weak navigationController] in
                navigationController?.popViewController(animated: true)
            },
            onPop: removeCollectibles
        )
    }

    func openNFTDetails(wallet: Wallet, nft: NFT) {
        guard let wallet = keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: wallet.id) else {
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
            self?.collectiblesDidOpenDapp?(url, title)
        }

        coordinator.didClose = { [weak self, weak coordinator, weak navigationController] in
            navigationController?.dismiss(animated: true)
            guard let coordinator else { return }
            self?.removeChild(coordinator)
            self?.collectiblesDetailsCoordinator = nil
        }

        coordinator.didRequestDeeplinkHandling = { [weak self] deeplink, utm in
            self?.didRequestDeeplinkHandling?(deeplink, utm)
        }

        coordinator.didRequestOpenBuySell = { [weak self] isInternalPurchasing in
            self?.collectiblesDidRequestOpenBuySell?(isInternalPurchasing, wallet)
        }

        coordinator.didRequestDepositTon = { [weak self] in
            self?.collectiblesDidRequestDepositTon?(wallet)
        }

        collectiblesDetailsCoordinator = coordinator
        coordinator.start()
        addChild(coordinator)

        router.present(navigationController, onDismiss: { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
            self?.collectiblesDetailsCoordinator = nil
        })
    }

    func getPasscode() async -> String? {
        return await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess,
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            analyticsProvider: coreAssembly.analyticsProvider
        )
    }
}
