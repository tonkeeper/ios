import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

public final class BatteryRefillCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let wallet: Wallet
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       wallet: Wallet,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.wallet = wallet
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }
  
  public override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
    openBatteryRefill()
  }
}

private extension BatteryRefillCoordinator {
  func openBatteryRefill() {
    let module = BatteryRefillAssembly.module(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    module.output.didTapSupportedTransactions = { [weak self] in
      self?.openSupportedTransactions()
    }
    
    module.output.didTapTransactionsSettings = { [weak self] in
      self?.openTransactionsSettings()
    }
    
    module.output.didTapRecharge = { [weak self] rechargeMethod in
      switch rechargeMethod {
      case let .token(token, _, rate):
        self?.openRecharge(token: token, rate: rate, isGift: false)
      case let .gift(token, rate):
        self?.openRecharge(token: token, rate: rate, isGift: true)
      }
      
    }
    
    router.push(viewController: module.view, animated: true)
  }
  
  func openSupportedTransactions() {
    let module = BatteryRefillSupportedTransactionsAssembly.module(
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    router.push(viewController: module.view)
  }
  
  func openTransactionsSettings() {
    let module = BatteryRefillTransactionsSettingsAssembly.module(
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    router.push(viewController: module.view)
  }
  
  func openRecharge(token: Token, rate: NSDecimalNumber?, isGift: Bool) {
    let module = BatteryRechargeAssembly.module(
      wallet: wallet,
      token: token,
      rate: rate,
      configuration: BatteryRechargeViewModelConfiguration(isGift: isGift),
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    router.present(module.view)
  }
}
