import UIKit
import TKCoordinator
import TKLocalize
import TKUIKit
import KeeperCore
import TKCore
import TonSwift
import BigInt

final class SendTokenCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didSendSuccessfully: ((SendTokenCoordinator?) -> Void)?
  var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)?

  private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
  
  private let wallet: Wallet
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let sendItem: SendItem
  private let recipient: Recipient?
  private let comment: String?
  
  init(router: NavigationControllerRouter,
       wallet: Wallet,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       sendItem: SendItem,
       recipient: Recipient? = nil,
       comment: String? = nil) {
    self.wallet = wallet
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.sendItem = sendItem
    self.recipient = recipient
    self.comment = comment
    super.init(router: router)
  }
  
  public override func start() {
    // If amount and recipient are set, we should force confirmation screen
    if isReadyForConfirmation() {
      openSendConfirmation(sendModel: .init(wallet: wallet, recipient: recipient, sendItem: sendItem, comment: comment))
    } else {
      openSend()
    }
  }
  
  public func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
    guard let walletTransferSignCoordinator = walletTransferSignCoordinator else { return false }
    walletTransferSignCoordinator.externalSignHandler?(sign)
    walletTransferSignCoordinator.externalSignHandler = nil
    return true
  }
  
  override func didMoveTo(toParent parent: (any Coordinator)?) {
    if parent == nil {
      walletTransferSignCoordinator?.externalSignHandler?(nil)
    }
  }
}

private extension SendTokenCoordinator {

  func openSend() {
    let module = SendV3Assembly.module(
      wallet: wallet,
      sendItem: sendItem,
      recipient: recipient,
      comment: comment,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    module.output.didContinueSend = { [weak self] sendModel in
      self?.openSendConfirmation(sendModel: sendModel)
    }
    
    module.output.didTapPicker = { [weak self] wallet, token in
      guard let self else { return }
      self.openTokenPicker(
        wallet: wallet,
        token: token,
        sourceViewController: self.router.rootViewController,
        completion: { token in
          module.input.updateWithToken(token)
        })
    }
    
    module.output.didTapScan = { [weak self] in
      self?.openScan(completion: { deeplink in
        switch deeplink {
        case .transfer(let data):
          switch data {
            case .sendTransfer(let sendTransferData):
              module.input.setRecipient(string: sendTransferData.recipient)
              module.input.setAmount(amount: sendTransferData.amount)
              module.input.setComment(comment: sendTransferData.comment)
            default: break
          }
          default: break
        }
      })
    }
    
    module.output.didTapClose = { [weak self] in
      self?.didFinish?(self)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openTokenPicker(wallet: Wallet, token: Token, sourceViewController: UIViewController, completion: @escaping (Token) -> Void) {
    let model = SendTokenPickerModel(
      wallet: wallet,
      selectedToken: token,
      balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore
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
    
    bottomSheetViewController.present(fromViewController: sourceViewController)
  }
  
  func openScan(completion: @escaping (KeeperCore.Deeplink) -> Void) {
    let scanModule = ScannerModule(
      dependencies: ScannerModule.Dependencies(
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
      )
    ).createScannerModule(configurator: DefaultScannerControllerConfigurator(),
                          uiConfiguration: ScannerUIConfiguration(title: TKLocales.Scanner.title,
                                                                  subtitle: nil,
                                                                  isFlashlightVisible: true))
    
    let navigationController = TKNavigationController(rootViewController: scanModule.view)
    navigationController.configureTransparentAppearance()
    
    scanModule.output.didScanDeeplink = { [weak self] deeplink in
      self?.router.dismiss(completion: {
        completion(deeplink)
      })
    }
    
    router.present(navigationController)
  }
}

// MARK: - SendConfirmation

private extension SendTokenCoordinator {

  func isReadyForConfirmation() -> Bool {
    switch sendItem {
    case .token(_, let amount):
      return !amount.isZero && recipient != nil
    case .nft:
      return recipient != nil
    }
  }

  func configureAndShowInsufficientPopup(wallet: Wallet,
                                         caption: String? = nil,
                                         buttonTitle: String,
                                         amount: BigUInt?,
                                         tokenSymbol: String?,
                                         fractionDigits: Int,
                                         balance: BigUInt,
                                         isInternalPurchasing: Bool) {
    var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    buyButtonConfiguration.content = TKButton.Configuration.Content(
      title: .plainString(buttonTitle)
    )
    buyButtonConfiguration.action = { [weak self] in
      self?.router.dismiss(animated: true) {
        self?.didRequestOpenBuySell?(isInternalPurchasing)
        self?.didFinish?(self)
      }
    }

    let builder = InfoPopupBottomSheetConfigurationBuilder(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    let configuration = builder.insufficientTokenConfiguration(
      walletLabel: wallet.metaData.label,
      caption: caption,
      tokenSymbol: tokenSymbol ?? Token.ton.symbol,
      tokenFractionalDigits: fractionDigits,
      required: amount ?? 0,
      available: balance,
      buttons: [buyButtonConfiguration]
    )

    openInsufficientFundsPopup(configuration: configuration)
  }

  func openInsufficientFundsPopup(configuration: InfoPopupBottomSheetViewController.Configuration) {
    let viewController = InfoPopupBottomSheetViewController()
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
    viewController.configuration = configuration
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }

  func openSendConfirmation(sendModel: SendModel) {
    guard let recipient = sendModel.recipient else { return }
    let transactionConfirmationController: TransactionConfirmationController
    switch sendModel.sendItem {
    case let .token(token, amount):
      switch token {
      case .ton:
        transactionConfirmationController = keeperCoreMainAssembly.tonTransferTransactionConfirmationController(
          wallet: wallet,
          recipient: recipient,
          amount: amount,
          comment: sendModel.comment
        )
      case .jetton(let jettonItem):
        transactionConfirmationController = keeperCoreMainAssembly.jettonTransferTransactionConfirmationController(
          wallet: wallet,
          recipient: recipient,
          jettonItem: jettonItem,
          amount: amount,
          comment: sendModel.comment)
      }
    case .nft(let nft):
      transactionConfirmationController = keeperCoreMainAssembly.nftTransferTransactionConfirmationController(
        wallet: wallet,
        recipient: recipient,
        nft: nft,
        comment: sendModel.comment
      )
    }

    let module = TransactionConfirmationAssembly.module(
      transactionConfirmationController: transactionConfirmationController,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    module.output.didRequireSign = { [weak self, keeperCoreMainAssembly, coreAssembly] walletTransfer, wallet in
      guard let self = self else { return nil }
      let coordinator = WalletTransferSignCoordinator(
        router: ViewControllerRouter(rootViewController: router.rootViewController),
        wallet: wallet,
        transferData: walletTransfer,
        keeperCoreMainAssembly: keeperCoreMainAssembly,
        coreAssembly: coreAssembly
      )

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

    module.output.didClose = { [weak self] in
      self?.didFinish?(self)
    }

    module.output.didConfirmTransaction = { [weak self] in
      self?.didSendSuccessfully?(self)
    }

    module.output.didProduceInsufficientFundsError = { [weak self] error in
      guard let self else {
        return
      }
      
      switch error {
      case .unknownJetton:
        ToastPresenter.showToast(configuration: .failed)
      case let .blockchainFee(wallet, balance, amount):
        let tonToken = Token.ton
        let amountFormatter = self.keeperCoreMainAssembly.formattersAssembly.amountFormatter
        let feeFormatted = amountFormatter.formatAmount(amount, fractionDigits: tonToken.fractionDigits, maximumFractionDigits: 2)
        let balanceFormatted = amountFormatter.formatAmount(balance, fractionDigits: tonToken.fractionDigits, maximumFractionDigits: 2)
        let caption = TKLocales.InsufficientFunds.feeRequired(feeFormatted, balanceFormatted)
        let buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(tonToken.symbol)

        configureAndShowInsufficientPopup(
          wallet: wallet,
          caption: caption,
          buttonTitle: buttonTitle,
          amount: amount,
          tokenSymbol: tonToken.symbol,
          fractionDigits: tonToken.fractionDigits,
          balance: balance,
          isInternalPurchasing: true
        )
      case let .insufficientFunds(jettonInfo, balance, requiredAmount, wallet, isInternalPurchasing):
        self.configureAndShowInsufficientPopup(
          wallet: wallet,
          buttonTitle: TKLocales.InsufficientFunds.rechargeWallet,
          amount: requiredAmount,
          tokenSymbol: jettonInfo?.symbol ?? jettonInfo?.name,
          fractionDigits: jettonInfo?.fractionDigits ?? 2,
          balance: balance,
          isInternalPurchasing: isInternalPurchasing
        )
      }
    }

    router.push(viewController: module.view)
  }
}
