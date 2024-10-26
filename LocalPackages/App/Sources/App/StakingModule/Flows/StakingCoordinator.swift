import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift

final class StakingCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
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
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    module.view.setupLeftButton(image: .TKUIKit.Icons.Size16.informationCircle) { [keeperCoreMainAssembly, coreAssembly] in
      Task {
        guard let url = await keeperCoreMainAssembly.configurationAssembly.configurationStore.getConfiguration().stakingInfoUrl else {
          return
        }
        await MainActor.run {
          coreAssembly.urlOpener().open(url: url)
        }
      }
    }
    
    module.output.didConfirm = { [weak self] item in
      guard let self else { return }
      self.openConfirmation(wallet: self.wallet, item: item)
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
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.view.setupBackButton()
    
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
  
  func openConfirmation(wallet: Wallet, item: StakingConfirmationItem) {
    let controller: StakeConfirmationController
    switch item.operation {
    case .deposit(let stackingPoolInfo):
      controller = keeperCoreMainAssembly.stakingDepositConfirmationController(
        wallet: wallet,
        stakingPool: stackingPoolInfo,
        amount: item.amount,
        isMax: item.isMax
      )
    case .withdraw(let stackingPoolInfo):
      return
    }
    
    let module = StakingConfirmationAssembly.module(wallet: wallet,
                                                    stakingConfirmationController: controller)

    module.output.didRequireSign = { [weak self, keeperCoreMainAssembly, coreAssembly] walletTransfer, wallet in
      guard let self = self else { return nil }
      let coordinator = await WalletTransferSignCoordinator(
        router: ViewControllerRouter(rootViewController: router.rootViewController),
        wallet: wallet,
        transferMessageBuilder: walletTransfer,
        keeperCoreMainAssembly: keeperCoreMainAssembly,
        coreAssembly: coreAssembly)
      
      self.walletTransferSignCoordinator = coordinator
      
      let result = await coordinator.handleSign(parentCoordinator: self)
    
      switch result {
      case .signed(let data):
        return data
      case .cancel:
        return nil
      case .failed(let error):
        throw error
      }
    }
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
}
