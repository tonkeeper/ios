import UIKit
import TKCoordinator
import TKLocalize
import TKUIKit
import TKScreenKit
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
  private let recipientResolver: RecipientResolver
  private let sendItem: SendV3Item
  private let recipient: Recipient?
  private let comment: String?
  
  init(router: NavigationControllerRouter,
       wallet: Wallet,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       recipientResolver: RecipientResolver,
       sendItem: SendV3Item,
       recipient: Recipient? = nil,
       comment: String? = nil) {
    self.wallet = wallet
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.recipientResolver = recipientResolver
    self.sendItem = sendItem
    self.recipient = recipient
    self.comment = comment
    super.init(router: router)
  }
  
  public override func start() {
    // If amount and recipient are set, we should force confirmation screen
    if isReadyForConfirmation(), let sendData = SendData.sendData(
      wallet: wallet,
      recipient: recipient,
      item: sendItem,
      comment: comment) {
      openSendConfirmation(sendData: sendData)
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
      item: sendItem,
      recipient: recipient,
      comment: comment,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    module.output.didContinueSend = { [weak self] sendData in
      self?.openSendConfirmation(sendData: sendData)
    }
    
    module.output.didTapPicker = { [weak self] wallet, token in
      var pickerToken: SendTokenPickerModel.PickerToken = .ton(.ton)
      switch token {
      case .ton(let ton):
        switch ton {
        case .nft: return
        case .token(let token, _):
          pickerToken = .ton(token)
        }
      case .tron(let tron):
        switch tron {
        case .usdt:
          pickerToken = .tronUSDT
        }
      }
      
      
      guard let self else { return }
      self.openTokenPicker(
        wallet: wallet,
        token: pickerToken,
        sourceViewController: self.router.rootViewController,
        completion: { token in
          module.input.updateWithToken(token)
        })
    }
    
    module.output.didTapScan = { [weak self] in
      self?.openScan(completion: { deeplink in
        Task { [weak self] in
          guard let self else { return }
          switch deeplink {
          case .transfer(let data):
            switch data {
            case .sendTransfer(let sendTransferData):
              let recipient = try await self.recipientResolver.resolverRecipient(
                string: sendTransferData.recipient,
                isTestnet: wallet.isTestnet
              )
              switch recipient {
              case .ton:
                module.input.setRecipient(string: sendTransferData.recipient)
                module.input.setAmount(amount: sendTransferData.amount)
                module.input.setComment(comment: sendTransferData.comment)
              case .tron:
                module.input.setRecipient(string: sendTransferData.recipient)
                module.input.updateWithToken(.tron(.usdt(amount: sendTransferData.amount ?? 0)))
                module.input.setComment(comment: sendTransferData.comment)
              }
            default: break
            }
          default: break
          }
        }
      })
    }
    
    module.output.didTapClose = { [weak self] in
      self?.didFinish?(self)
    }
    
    module.output.didOpenURL = { [weak self] url in
      self?.openURL(url, title: nil)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openTokenPicker(wallet: Wallet,
                       token: SendTokenPickerModel.PickerToken,
                       sourceViewController: UIViewController,
                       completion: @escaping (SendV3Item) -> Void) {
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
      let sendToken: SendV3Item = {
        switch token {
        case .ton(let ton):
          switch ton {
          case .ton:
            return .ton(.token(.ton, amount: 0))
          case .jetton(let jettonInfo):
            return .ton(.token(.jetton(jettonInfo), amount: 0))
          }
        case .tronUSDT:
          return .tron(.usdt(amount: 0))
        }
      }()
      completion(sendToken)
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
  
  func openURL(_ url: URL, title: String?) {
    let viewController = TKBridgeWebViewController(
      initialURL: url,
      initialTitle: nil,
      jsInjection: nil,
      configuration: .default,
      userAgentProvider: TonkeeperBridgeWebViewControllerUserAgentProvider())
    router.present(viewController)
  }
}

// MARK: - SendConfirmation

private extension SendTokenCoordinator {

  func isReadyForConfirmation() -> Bool {
    switch sendItem {
    case .ton(let item):
      switch item {
      case .token(_, let amount):
        return !amount.isZero && recipient != nil && recipient?.isTon == true
      case .nft:
        return recipient != nil && recipient?.isTon == true
      }
    case .tron(let item):
      switch item {
      case .usdt(let amount):
        return !amount.isZero && recipient != nil && recipient?.isTron == true
      }
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
      tokenSymbol: tokenSymbol ?? TonToken.ton.symbol,
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

  func openSendConfirmation(sendData: SendData) {
    let transactionConfirmationController: TransactionConfirmationController
    switch sendData {
    case .ton(let ton):
      switch ton.item {
      case let .token(token, amount):
        switch token {
        case .ton:
          transactionConfirmationController = keeperCoreMainAssembly.tonTransferTransactionConfirmationController(
            wallet: ton.wallet,
            recipient: ton.recipient,
            amount: amount,
            comment: ton.comment,
            isMaxAmount: false
          )
        case .jetton(let jettonItem):
          transactionConfirmationController = keeperCoreMainAssembly.jettonTransferTransactionConfirmationController(
            wallet: ton.wallet,
            recipient: ton.recipient,
            jettonItem: jettonItem,
            amount: amount,
            comment: ton.comment)
        }
      case .nft(let nft):
        transactionConfirmationController = keeperCoreMainAssembly.nftTransferTransactionConfirmationController(
          wallet: ton.wallet,
          recipient: ton.recipient,
          nft: nft,
          comment: ton.comment
        )
      }
    case .tron(let tron):
      switch tron.item {
      case .usdt(let amount):
        let confirmationController = keeperCoreMainAssembly.tronUSDTTransferTransactionConfirmationController(
          wallet: tron.wallet,
          recipient: tron.recipient,
          amount: amount
        )
        confirmationController.tronSignHandler = { [weak self, keeperCoreMainAssembly, coreAssembly] txId, wallet in
          guard let self = self else { return nil }
          let coordinator = TronUSDTTransferSignCoordinator(router: ViewControllerRouter(rootViewController: router.rootViewController),
                                                            wallet: wallet,
                                                            txID: txId,
                                                            keeperCoreMainAssembly: keeperCoreMainAssembly,
                                                            coreAssembly: coreAssembly)
          let result = await coordinator.handleSign(parentCoordinator: self)
          switch result {
          case .signed(let signature):
            return signature
          case .cancel:
            return nil
          case .failed(let error):
            throw error
          }
        }
        transactionConfirmationController = confirmationController
      }
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

      let symbol: String
      let fractionDigits: Int
      let buttonTitle: String
      let caption: String?
      let amount: BigUInt
      let availableBalance: BigUInt
      let internalPurchasingFlow: Bool

      switch error {
      case .unknownJetton:
        ToastPresenter.showToast(configuration: .failed)
        return
      case let .blockchainFee(_, balance, requiredAmount):
        let tonToken = TonToken.ton
        let token = TonToken.ton
        symbol = token.symbol
        fractionDigits = token.fractionDigits
        amount = requiredAmount
        availableBalance = balance

        let amountFormatter = self.keeperCoreMainAssembly.formattersAssembly.amountFormatter
        let feeFormatted = amountFormatter.formatAmount(amount, fractionDigits: tonToken.fractionDigits, maximumFractionDigits: 2)
        let balanceFormatted = amountFormatter.formatAmount(balance, fractionDigits: tonToken.fractionDigits, maximumFractionDigits: 2)
        caption = TKLocales.InsufficientFunds.feeRequired(feeFormatted, balanceFormatted)
        buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(tonToken.symbol)

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
          fractionDigits = TonToken.ton.fractionDigits
          symbol = TonToken.ton.symbol
          buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(symbol)
        }

        internalPurchasingFlow = isInternalPurchasing
      }

      self.configureAndShowInsufficientPopup(
        wallet: self.wallet,
        caption: caption,
        buttonTitle: buttonTitle,
        amount: amount,
        tokenSymbol: symbol,
        fractionDigits: fractionDigits,
        balance: availableBalance,
        isInternalPurchasing: internalPurchasingFlow)
    }

    router.push(viewController: module.view)
  }
}
