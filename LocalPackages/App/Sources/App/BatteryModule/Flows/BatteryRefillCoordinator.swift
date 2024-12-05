import UIKit
import TKCoordinator
import TKUIKit
import TKCore
import TKLocalize
import KeeperCore
import SignRaw

public final class BatteryRefillCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didOpenRefundURL: ((_ url: URL, _ title: String) -> Void)?
  
  private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
  
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
    guard let walletTransferSignCoordinator = walletTransferSignCoordinator else { return false }
    walletTransferSignCoordinator.externalSignHandler?(sign)
    walletTransferSignCoordinator.externalSignHandler = nil
    return true
  }
}

private extension BatteryRefillCoordinator {
  func openBatteryRefill() {
    let promocodeStore = keeperCoreMainAssembly.batteryAssembly.batteryPromocodeStore()
    
    let module = BatteryRefillAssembly.module(
      wallet: wallet,
      promocodeStore: promocodeStore,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    module.output.didTapSupportedTransactions = { [weak self] in
      guard let self else { return }
      openSupportedTransactions(wallet: wallet)
    }
    
    module.output.didTapTransactionsSettings = { [weak self] in
      self?.openTransactionsSettings()
    }
    
    module.output.didFinish = { [weak self] in
      self?.didFinish?(self)
    }
    
    module.output.didTapRecharge = { [weak self] rechargeMethod in
      switch rechargeMethod {
      case let .token(token):
        self?.openRecharge(token: token,
                           isGift: false,
                           promocodeStore: promocodeStore)
      case let .gift(token):
        self?.openRecharge(token: token,
                           isGift: true,
                           promocodeStore: promocodeStore)
      }
    }
    
    module.output.didOpenRefundURL = { [weak self] url, title in
      self?.didOpenRefundURL?(url, title)
    }
    
    router.push(viewController: module.view, animated: true)
  }
  
  func openSupportedTransactions(wallet: Wallet) {
    let module = BatteryRefillSupportedTransactionsAssembly.module(
      wallet: wallet,
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
  
  func openRecharge(token: Token,
                    isGift: Bool,
                    promocodeStore: BatteryPromocodeStore) {
    let module = BatteryRechargeAssembly.module(
      wallet: wallet,
      token: token,
      isGift: isGift,
      promocodeStore: promocodeStore,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    module.output.didTapContinue = { [weak self] payload in
      self?.openConfirmation(payload: payload)
    }
    
    weak var moduleInput = module.input
    module.output.didSelectTokenPicker = { [weak self] in
      self?.openTokenPicker(token: $0, completion: { token in
        moduleInput?.setToken(token: token)
      })
    }
    
    router.present(module.view)
  }
  
  func openConfirmation(payload: BatteryRechargePayload) {
    guard let windowScene = router.rootViewController.view.window?.windowScene else { return }
    
    
    let batteryRechargeSignRawBuilder = BatteryRechargeSignRawBuilder(
      wallet: wallet,
      payload: payload,
      batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
      sendService: keeperCoreMainAssembly.servicesAssembly.sendService(),
      tonProofTokenService: keeperCoreMainAssembly.servicesAssembly.tonProofTokenService(),
      configuration: keeperCoreMainAssembly.configurationAssembly.configuration
    )
    
    SignRawPresenter.presentSignRaw(
      windowScene: windowScene,
      windowLevel: .signRaw,
      wallet: wallet,
      transferProvider: { try await batteryRechargeSignRawBuilder.getSignRawRequest() },
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      didRequireSign: { [weak self] transferData, wallet, coordinator, router in
        try await self?.didRequireSign(transferData: transferData,
                                       wallet: wallet,
                                       coordinator: coordinator,
                                       router: router)
      }
    )
  }
  
  func openTokenPicker(token: Token, completion: @escaping (Token) -> Void) {
    let model = BatteryTokenPickerModel(
      wallet: wallet,
      selectedToken: token,
      balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
      batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService()
    )
    
    let module = TokenPickerAssembly.module(
      wallet: wallet,
      model: model,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didSelectToken = { token in
      completion(token)
    }
    
    module.output.didFinish = {  [weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss()
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
  }
  
  @MainActor
  func didRequireSign(transferData: TransferData,
                      wallet: Wallet,
                      coordinator: Coordinator,
                      router: ViewControllerRouter) async throws -> String? {
    let coordinator = WalletTransferSignCoordinator(
      router: router,
      wallet: wallet,
      transferData: transferData,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly)
    
    self.walletTransferSignCoordinator = coordinator
    
    let result = await coordinator.handleSign(parentCoordinator: coordinator)
  
    switch result {
    case .signed(let data):
      return data
    case .cancel:
      return nil
    case .failed(let error):
      throw error
    }
  }
}
