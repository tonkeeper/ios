import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import KeeperCore

public final class BatteryRefillCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private weak var signTransactionConfirmationCoordinator: SignTransactionConfirmationCoordinator?
  
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
  
  public func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
    guard let signTransactionConfirmationCoordinator = signTransactionConfirmationCoordinator else { return false }
    return signTransactionConfirmationCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
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
    
    module.output.didTapContinue = { [weak self] payload in
      self?.openConfirmation(payload: payload)
    }
    
    router.present(module.view)
  }
  
  func openConfirmation(payload: BatteryRechargePayload) {
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = TKWindow(windowScene: windowScene)
    
    let bocBuilder = BatteryRechargeBocBuilder(
      wallet: wallet,
      payload: payload,
      batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
      sendService: keeperCoreMainAssembly.servicesAssembly.sendService(),
      tonProofTokenService: keeperCoreMainAssembly.servicesAssembly.tonProofTokenService(),
      configuration: keeperCoreMainAssembly.configurationAssembly.configuration
    )
    
    let coordinator = SignTransactionConfirmationCoordinator(
      router: WindowRouter(window: window),
      wallet: wallet,
      confirmator: BatteryRechargeSignTransactionConfirmationCoordinatorConfirmator(
        bocBuilder: bocBuilder,
        sendService: keeperCoreMainAssembly.servicesAssembly.sendService()
      ),
      confirmTransactionController: keeperCoreMainAssembly.confirmTransactionController(
        wallet: wallet,
        bocProvider: BatteryRechargeConfirmTransactionControllerBocProvider(
          bocBuilder: bocBuilder
        )
      ),
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
//      self?.didCancel?()
    }
    
    coordinator.didConfirm = { [weak self, weak coordinator] in
      self?.removeChild(coordinator)
//      self?.didFinish?()
    }
    
    self.signTransactionConfirmationCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start()
  }
}
