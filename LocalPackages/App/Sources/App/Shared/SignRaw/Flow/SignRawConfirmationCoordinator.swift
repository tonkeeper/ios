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

  var didRequireSign: ((TransferData, Wallet, UIViewController) async throws -> SignedTransactions?)?
  var didRequestShowInfoPopup: ((_ title: String, _ caption: String) -> Void)?
  var didRequestReplanishWallet: ((_ wallet: Wallet, _ isInternalPurchasing: Bool) -> Void)?

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
    module.output.didCancel = { [weak self] in
      guard let self else { return }
      self.didFinish?(self)
    }
    module.output.didRequestShowInfoPopup = { [weak self] title, caption in
      self?.openInfoPopup(title: title, caption: caption)
    }
    module.output.didRequireShowInsufficientPopup = { [weak self, weak containerViewController] wallet, error in
      guard let self else { return }
      let symbol: String
      let fractionDigits: Int
      let buttonTitle: String
      let caption: String?
      let amount: BigUInt
      let availableBalance: BigUInt
      let internalPurchasingFlow: Bool

      switch error {
      case let .blockchainFee(_, balance, requiredAmount):
        let token = Token.ton
        symbol = token.symbol
        fractionDigits = token.fractionDigits
        amount = requiredAmount
        availableBalance = balance

        let amountFormatter = self.keeperCoreMainAssembly.formattersAssembly.amountFormatter
        let feeFormatted = amountFormatter.formatAmount(amount, fractionDigits: fractionDigits, maximumFractionDigits: 2)
        let balanceFormatted = amountFormatter.formatAmount(balance, fractionDigits: fractionDigits, maximumFractionDigits: 2)
        caption = TKLocales.InsufficientFunds.feeRequired(feeFormatted, balanceFormatted)
        buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(token.symbol)
        internalPurchasingFlow = true
      case let .insufficientFunds(jettonInfo, balance, requiredAmount, _, isInternalPurchasing):
        caption = nil
        amount = requiredAmount
        availableBalance = balance

        if let jettonInfo {
          fractionDigits = jettonInfo.fractionDigits
          symbol = jettonInfo.symbol ?? jettonInfo.name
          buttonTitle = TKLocales.InsufficientFunds.rechargeWallet
        } else {
          fractionDigits = Token.ton.fractionDigits
          symbol = Token.ton.symbol
          buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(symbol)
        }
        internalPurchasingFlow = isInternalPurchasing
      case .unknownJetton:
        return
      }

      moduleInput?.cancel()
      containerViewController?.dismiss {
        self.startInsufficientFlow(
          wallet: wallet,
          caption: caption,
          buttonTitle: buttonTitle,
          symbol: symbol,
          fractionDigits: fractionDigits,
          required: amount,
          available: availableBalance,
          isInternalPurchasing: internalPurchasingFlow
        )
      }
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
    caption: String?,
    buttonTitle: String,
    symbol: String,
    fractionDigits: Int,
    required: BigUInt,
    available: BigUInt,
    isInternalPurchasing: Bool
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
    buyButtonConfiguration.content = TKButton.Configuration.Content(
      title: .plainString(buttonTitle)
    )
    buyButtonConfiguration.action = { [weak bottomSheetViewController, weak self] in
      bottomSheetViewController?.dismiss() {
        self?.didRequestReplanishWallet?(wallet, isInternalPurchasing)
        self?.didFinish?(self)
      }
    }

    bottomSheetViewController.didClose = { [weak self] _ in
      self?.didFinish?(self)
    }
    let configuration = configurationBuilder.insufficientTokenConfiguration(
      walletLabel: wallet.metaData.label,
      caption: caption,
      tokenSymbol: symbol,
      tokenFractionalDigits: fractionDigits,
      required: required,
      available: available,
      buttons: [buyButtonConfiguration]
    )
    viewController.configuration = configuration
    ToastPresenter.hideAll()
    bottomSheetViewController.present(fromViewController: rootViewController)
  }
}
