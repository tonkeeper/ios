import UIKit
import TKCoordinator
import TKLocalize
import TKUIKit
import KeeperCore
import TKCore
import TonSwift
import BigInt

final class SendTokenCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
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
    openSend()
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
          module.input.setRecipient(string: data.recipient)
          module.input.setAmount(amount: data.amount)
          module.input.setComment(comment: data.comment)
          default: break
        }
      })
    }
    
    module.output.didTapClose = { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: module.view, animated: false)
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
    
    module.output.didClose = { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: module.view)
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
