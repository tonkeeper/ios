import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift

final class StakingCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  var didClose: (() -> Void)?
  
  private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
  
  private let wallet: Wallet
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(wallet: Wallet,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    
    super.init(router: router)
  }
  
  override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
    openStakingDepositInput()
  }
  
  func openStakingDepositInput() {
    let stakingDepositInputPoolPicker = StakingDepositInputPoolPickerAssembly.module(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    let configurator = StakingDepositInputModelConfigurator(
      wallet: wallet,
      balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore
    )

    let module = StakingInputAssembly.module(
      model: StakingInputModelImplementation(
        wallet: wallet,
        detailsInput: stakingDepositInputPoolPicker.input,
        configurator: configurator,
        stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
        tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
        currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore
      ),
      detailsViewController: stakingDepositInputPoolPicker.view,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    module.output.didConfirm = { [weak self] item in
      guard let self else { return }
      Task {
        await MainActor.run {
          self.openConfirmation(wallet: self.wallet, item: item)
        }
      }
    }
    
    module.output.didClose = { [weak self] in
      self?.didClose?()
    }
    
    stakingDepositInputPoolPicker.view.didTapPicker = { [weak self, module] model in
      self?.openStakingList(model: model, poolSelectionClosure: { pool in
        module.input.setPool(pool)
        self?.router.popToRoot()
      })
    }
  
    router.push(viewController: module.view)
  }
  
  func openStakingList(model: StakingListModel, poolSelectionClosure: @escaping (StackingPoolInfo) -> Void) {
    let module = StakingListAssembly.module(
      model: model,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    module.output.didSelectGroup = { [weak self] group in
      let model = StakingListModel(
        title: group.name,
        sections: [StakingListSection(title: nil, items: group.items.map { .pool($0) })],
        selectedPool: model.selectedPool
      )
      self?.openStakingList(model: model, poolSelectionClosure: poolSelectionClosure)
    }
    
    module.output.didSelectPool = { [weak self] pool in
      self?.openStakingPoolDetails(pool: pool, poolSelectionClosure: { selectedPool in
        poolSelectionClosure(selectedPool)
      })
    }
    
    module.output.didClose = { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: module.view)
  }
  
  func openStakingPoolDetails(pool: StakingListPool, poolSelectionClosure: @escaping (StackingPoolInfo) -> Void) {
    let module = StakingPoolDetailsAssembly.module(pool: pool, keeperCoreMainAssembly: keeperCoreMainAssembly)
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.view.setupBackButton()
    
    module.output.didSelectPool = {
      poolSelectionClosure($0)
    }
    
    module.output.didOpenURL = { [weak self] in
      self?.coreAssembly.urlOpener().open(url: $0)
    }
    
    module.output.didOpenURLInApp = { [weak self] url, title in
      self?.openURL(url, title: title)
    }
    
    module.output.didClose = { [weak self] in
      self?.didClose?()
    }
    
    router.push(viewController: module.view)
  }
  
  func openURL(_ url: URL, title: String?) {
    let viewController = TKBridgeWebViewController(
      initialURL: url,
      initialTitle: nil,
      jsInjection: nil,
      configuration: .default)
    router.present(viewController)
  }
  
  @MainActor func openConfirmation(wallet: Wallet, item: StakingConfirmationItem) {
    let coordinator = StakingConfirmationCoordinator(
      wallet: wallet,
      item: item,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: router
    )
    
    coordinator.didFinish = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
    }
    
    coordinator.didClose = { [weak self, weak coordinator] in
      self?.didClose?()
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start(deeplink: nil)
  }
}
