import KeeperCore
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

public final class WalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didTapScan: (() -> Void)?
    var didLogout: (() -> Void)?
    var didTapWalletButton: (() -> Void)?
    var didTapWithdraw: (([Token], _ wallet: Wallet) -> Void)?
    var didTapDeposit: (([Token], _ wallet: Wallet) -> Void)?
    var didTapSend: ((Wallet, TonToken) -> Void)?
    var didTapBuy: ((Wallet) -> Void)?
    var didTapReceive: (([Token], _ wallet: Wallet) -> Void)?
    var didTapSwap: ((Wallet) -> Void)?
    var didTapStake: ((Wallet) -> Void)?
    var didTapStory: ((Story) -> Void)?
    var didTapAllUpdates: (() -> Void)?
    var didTapSupportButton: (() -> Void)?
    var didTapSettingsButton: ((Wallet) -> Void)?
    var didSelectTonDetails: ((Wallet) -> Void)?
    var didSelectJettonDetails: ((Wallet, JettonItem, Bool) -> Void)?
    var didSelectTronUSDTDetails: ((Wallet) -> Void)?
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
    var didTapStoriesOnboarding: ((String) -> Void)?

    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    private var configuration: Configuration {
        keeperCoreMainAssembly.configurationAssembly.configuration
    }

    init(
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        super.init(router: router)
        router.rootViewController.tabBarItem.title = TKLocales.Tabs.wallet
        router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.wallet
    }

    override public func start() {
        openWalletContainer()
    }
}

private extension WalletCoordinator {
    func openWalletContainer() {
        let module = WalletContainerAssembly.module(
            walletBalanceModule: createWalletBalanceModule(),
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            configuration: configuration
        )

        module.output.walletButtonHandler = { [weak self] in
            self?.didTapWalletButton?()
        }

        module.output.didTapSupportButton = { [weak self] in
            self?.didTapSupportButton?()
        }

        module.output.didTapScan = { [weak self] in
            self?.didTapScan?()
        }

        module.output.didTapSettingsButton = { [weak self] wallet in
            self?.didTapSettingsButton?(wallet)
        }

        router.push(viewController: module.view, animated: false)
    }

    func openManageTokens(wallet: Wallet) {
        let updateQueue = DispatchQueue(label: "ManageTokensQueue")

        let module = ManageTokensAssembly.module(
            model: ManageTokensModel(
                wallet: wallet,
                tokenManagementStore: keeperCoreMainAssembly.storesAssembly.tokenManagementStore,
                convertedBalanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
                stackingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
                updateQueue: updateQueue
            ),
            mapper: ManageTokensListMapper(amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter),
            updateQueue: updateQueue,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )

        let navigationController = TKNavigationController(rootViewController: module.view)
        navigationController.setNavigationBarHidden(true, animated: false)

        router.present(navigationController)
    }

    func createWalletBalanceModule() -> WalletBalanceModule {
        let module = WalletBalanceAssembly.module(
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

        module.output.didSelectEthena = { [weak self] wallet in
            self?.didSelectEthenaDetails?(wallet)
        }

        module.output.didSelectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStackingInfo in
            self?.didSelectStakingItem?(wallet, stakingPoolInfo, accountStackingInfo)
        }

        module.output.didSelectCollectStakingItem = { [weak self] wallet, stakingPoolInfo, accountStackingInfo in
            self?.didSelectCollectStakingItem?(wallet, stakingPoolInfo, accountStackingInfo)
        }

        module.output.didTapSend = { [weak self] wallet in
            self?.didTapSend?(wallet, .ton)
        }

        module.output.didTapReceive = { [weak self] wallet in
            guard let self else { return }

            let tokens = getTokens(wallet: wallet)
            didTapReceive?(tokens, wallet)
        }

        module.output.didTapWithdraw = { [weak self] wallet in
            guard let self else { return }

            let tokens = getTokens(wallet: wallet)
            didTapWithdraw?(tokens, wallet)
        }

        module.output.didTapDeposit = { [weak self] wallet in
            guard let self else { return }

            let tokens = getTokens(wallet: wallet)
            didTapDeposit?(tokens, wallet)
        }

        module.output.didTapScan = { [weak self] in
            self?.didTapScan?()
        }

        module.output.didTapBuy = { [weak self, weak coreAssembly] wallet in
            let analyticsProvider = coreAssembly?.analyticsProvider
            analyticsProvider?.log(
                eventKey: .onrampOpen,
                args: [
                    "from": "wallet",
                ]
            )
            self?.didTapBuy?(wallet)
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

        module.output.didTapStory = { [weak self] story in
            self?.didTapStory?(story)
        }

        module.output.didTapAllUpdates = { [weak self] in
            self?.didTapAllUpdates?()
        }

        module.output.didTapBattery = { [weak self] wallet in
            self?.didTapBattery?(wallet)
        }

        module.output.didTapManage = { [weak self] wallet in
            self?.openManageTokens(wallet: wallet)
        }

        module.output.didRequirePasscode = { [weak self] in
            await self?.getPasscode()
        }

        module.output.didTapStoriesOnboarding = { [weak self] storyId in
            self?.didTapStoriesOnboarding?(storyId)
        }

        return module
    }

    func getTokens(wallet: Wallet) -> [Token] {
        let balanceStore = keeperCoreMainAssembly.storesAssembly.balanceStore
        let tronBalanceIsZero = balanceStore.getState()[wallet]?.walletBalance.tronBalance?.amount.isZero ?? true
        let tronDisabled = configuration.flag(\.tronDisabled, network: wallet.network) && tronBalanceIsZero

        var tokens: [Token] = [.ton(.ton)]
        if !tronDisabled || wallet.isTronTurnOn, wallet.isTronAvailable {
            tokens.append(.tron(.usdt))
        }

        return tokens
    }

    func getPasscode() async -> String? {
        return await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
        )
    }
}
