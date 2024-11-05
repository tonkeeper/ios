import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

public final class WalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didTapScan: (() -> Void)?
  var didLogout: (() -> Void)?
  var didTapWalletButton: (() -> Void)?
  var didTapSend: ((Wallet, Token) -> Void)?
  var didTapBuy: ((Wallet) -> Void)?
  var didTapReceive: ((Token, _ wallet: Wallet) -> Void)?
  var didTapSwap: ((Wallet) -> Void)?
  var didTapStake: ((Wallet) -> Void)?
  var didTapSettingsButton: ((Wallet) -> Void)?
  var didSelectTonDetails: ((Wallet) -> Void)?
  var didSelectJettonDetails: ((Wallet, JettonItem, Bool) -> Void)?
  var didSelectStakingItem: (( _ wallet: Wallet,
                               _ stakingPoolInfo: StackingPoolInfo,
                               _ accountStakingInfo: AccountStackingInfo) -> Void)?
  var didSelectCollectStakingItem: (( _ wallet: Wallet,
                                      _ stakingPoolInfo: StackingPoolInfo,
                                      _ accountStakingInfo: AccountStackingInfo) -> Void)?
  var didTapBackup: ((Wallet) -> Void)?
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
    router.rootViewController.tabBarItem.title = TKLocales.Tabs.wallet
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.wallet
  }
  
  public override func start() {
    openWalletContainer()
  }
}

private extension WalletCoordinator {
  func openWalletContainer() {
    let module = WalletContainerAssembly.module(
      walletBalanceModule: createWalletBalanceModule(),
      walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore
    )
    
    module.output.walletButtonHandler = { [weak self] in
      self?.didTapWalletButton?()
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
      updateQueue: updateQueue
    )

    let navigationController = TKNavigationController(rootViewController: module.view)
    navigationController.setNavigationBarHidden(true, animated: false)
    
    router.present(navigationController)
  }

  func createWalletBalanceModule() -> WalletBalanceModule {
    let module = WalletBalanceAssembly.module(keeperCoreMainAssembly: keeperCoreMainAssembly,
                                              coreAssembly: coreAssembly)
    
    module.output.didSelectTon = { [weak self] wallet in
      self?.didSelectTonDetails?(wallet)
    }
    
    module.output.didSelectJetton = { [weak self] wallet, jettonItem, hasPrice in
      self?.didSelectJettonDetails?(wallet, jettonItem, hasPrice)
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
      self?.didTapReceive?(.ton, wallet)
    }
    
    module.output.didTapScan = { [weak self] in
      self?.didTapScan?()
    }
    
    module.output.didTapBuy = { [weak self] wallet in
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

    module.output.didTapManage = { [weak self] wallet in
      self?.openManageTokens(wallet: wallet)
    }
    
    module.output.didRequirePasscode = { [weak self] in
      await self?.getPasscode()
    }

    return module
  }
  
  func getPasscode() async -> String? {
    return await PasscodeInputCoordinator.getPasscode(
      parentCoordinator: self,
      parentRouter: router,
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
    )
  }
}
