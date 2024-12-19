import UIKit
import TKUIKit
import TKCore
import TKCoordinator
import KeeperCore
import SignRaw
import TKLocalize
import BigInt
import TonSwift

@MainActor
public final class SignRawConfirmationCoordinator: RouterCoordinator<WindowRouter> {

  var didRequireSign: ((TransferData, Wallet, UIViewController) async throws -> String?)?
  var didRequestShowInfoPopup: ((_ title: String, _ caption: String) -> Void)?
  var didRequestReplanishWallet: ((_ wallet: Wallet, _ context: ReplanishBalanceContext) -> Void)?

  public enum ReplanishBalanceContext {
    case inApp
    case defi
    case battery
  }

  private let wallet: Wallet
  private let transferProvider: () async throws -> Transfer
  private let resultHandler: SignRawControllerResultHandler?
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  public init(router: WindowRouter,
              wallet: Wallet,
              transferProvider: @escaping () async throws -> Transfer,
              resultHandler: SignRawControllerResultHandler?,
              keeperCoreMainAssembly: KeeperCore.MainAssembly,
              coreAssembly: TKCore.CoreAssembly) {
    self.wallet = wallet
    self.transferProvider = transferProvider
    self.resultHandler = resultHandler
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }

  public override func start() {
    openConfirmation()
  }
  
  private func openConfirmation() {
    let rootViewController = UIViewController()
    router.window.rootViewController = rootViewController
    router.window.makeKeyAndVisible()
    
    let module = SignRawConfirmationAssembly.module(
      wallet: wallet,
      transferProvider: transferProvider,
      resultHandler: resultHandler,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    weak var moduleInput = module.input
    let containerViewController = TKBottomSheetViewController(contentViewController: module.view)
    containerViewController.didClose = { [weak self] isInteractivly in
      guard let self else { return }
      guard isInteractivly else { return }
      moduleInput?.cancel()
      self.didFinish?(self)
    }
    
    module.output.didRequireSign = { [weak self] transferData, wallet in
      guard let self else { return nil }
      return try await didRequireSign?(transferData, wallet, containerViewController)
    }
    module.output.didConfirm = { [weak self] in
      guard let self else { return }
      self.didFinish?(self)
    }
    module.output.didRequestShowInfoPopup = { [weak self] title, caption in
      self?.openInfoPopup(title: title, caption: caption)
    }
    module.output.didRequireShowInsufficientPopup = { [weak self, weak containerViewController] wallet, provisionModel in
      let trustCoins: [Address] = [
        JettonMasterAddress.tonUSDT,
        JettonMasterAddress.NOT,
        JettonMasterAddress.HMSTR
      ]
      let token = provisionModel.token.token
      let isInAppPurchase: Bool
      switch token {
      case .ton:
        isInAppPurchase = true
      case .jetton(let info):
        isInAppPurchase = trustCoins.contains(info.jettonInfo.address)
      }
      moduleInput?.cancel()
      containerViewController?.dismiss(completion: {
        self?.startInsufficientFlow(wallet: wallet, model: provisionModel, isInAppPurchaseFlowAvailable: isInAppPurchase)
      })
    }

    containerViewController.present(fromViewController: rootViewController)
  }

  private func openInfoPopup(title: String, caption: String) {
    guard let rootViewController = router.window.rootViewController?.presentedViewController else {
      return
    }

    let viewController = InfoPopupBottomSheetViewController()
    let sheetViewController = TKBottomSheetViewController(contentViewController: viewController)

    var button = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    button.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.ok))
    button.action =  { [weak sheetViewController] in
      sheetViewController?.dismiss()
    }

    let configurationBuilder = InfoPopupBottomSheetConfigurationBuilder(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    let configuration = configurationBuilder.commonConfiguration(
      title: title, caption: caption, buttons: [button]
    )
    viewController.configuration = configuration
    sheetViewController.present(fromViewController: rootViewController)
  }

  @MainActor
  private func startInsufficientFlow(
    wallet: Wallet,
    model: SignRawConfirmationModel.ProvisionModel,
    isInAppPurchaseFlowAvailable: Bool
  ) {
    guard let rootViewController = router.window.rootViewController else {
      return
    }

    let viewController = InfoPopupBottomSheetViewController()
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
    let configurationBuilder = InfoPopupBottomSheetConfigurationBuilder(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )

    var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    let buttonTitle: String
    switch model.token.token {
    case .ton:
      buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(model.token.token.symbol)
    case .jetton:
      buttonTitle = TKLocales.InsufficientFunds.rechargeWallet
    }
    buyButtonConfiguration.content = TKButton.Configuration.Content(
      title: .plainString(buttonTitle)
    )
    buyButtonConfiguration.action = { [weak bottomSheetViewController, weak self] in
      bottomSheetViewController?.dismiss() {
        let context: ReplanishBalanceContext = isInAppPurchaseFlowAvailable ? .inApp : .defi
        self?.didRequestReplanishWallet?(wallet, context)
        self?.didFinish?(self)
      }
    }

    bottomSheetViewController.didClose = { [weak self] _ in
      self?.didFinish?(self)
    }
    let configuration = configurationBuilder.insufficientTokenConfiguration(
      walletLabel: wallet.metaData.label,
      tokenSymbol: model.token.token.symbol,
      tokenFractionalDigits: model.token.token.fractionDigits,
      required: BigUInt(integerLiteral: UInt64(model.requiredAmount)),
      available: BigUInt(integerLiteral: UInt64(model.token.availableBalance)),
      buttons: [buyButtonConfiguration]
    )
    viewController.configuration = configuration
    ToastPresenter.hideAll()
    bottomSheetViewController.present(fromViewController: rootViewController)
  }
}
