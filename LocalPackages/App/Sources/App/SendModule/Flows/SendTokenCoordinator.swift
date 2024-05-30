import UIKit
import TKCoordinator
import TKLocalize
import TKUIKit
import KeeperCore
import TKCore
import TonSwift

final class SendTokenCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
  private var externalSignHandler: ((Data) async -> Void)?
  
  private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let sendItem: SendItem
  private let recipient: Recipient?
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       sendItem: SendItem,
       recipient: Recipient? = nil ) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.sendItem = sendItem
    self.recipient = recipient
    super.init(router: router)
  }
  
  public override func start() {
    openSend()
  }
  
  public func handleTonkeeperPublishDeeplink(model: TonkeeperPublishModel) -> Bool {
    guard let externalSignHandler else { return false }
    Task {
      await externalSignHandler(model.boc)
    }
    self.externalSignHandler = nil
    return true
  }
}

private extension SendTokenCoordinator {
  func openSend() {
    let module = SendV3Assembly.module(
      sendItem: sendItem,
      recipient: recipient,
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
        case .ton(let tonDeeplink):
          switch tonDeeplink {
          case .transfer(let recipient, _):
            module.input.setRecipient(string: recipient)
          }
        default:
          break
        }
      })
    }
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openRecipientInput(sendModel: SendModel,
                          completion: @escaping (SendModel) -> Void) {
    openSendTokenEdit(sendModel: sendModel, step: .recipient, completion: completion)
  }
  
  func openAmountInput(sendModel: SendModel,
                       completion: @escaping (SendModel) -> Void) {
    openSendTokenEdit(sendModel: sendModel, step: .amount, completion: completion)
  }
  
  func openCommentInput(sendModel: SendModel,
                        completion: @escaping (SendModel) -> Void) {
    openSendTokenEdit(sendModel: sendModel, step: .comment, completion: completion)
  }
  
  func openSendTokenEdit(sendModel: SendModel,
                         step: SendTokenEditCoordinator.Step,
                         completion: @escaping (SendModel) -> Void) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    navigationController.setNavigationBarHidden(true, animated: false)
    navigationController.modalPresentationStyle = .fullScreen
    
    let coordinator = SendTokenEditCoordinator(
      step: step,
      sendModel: sendModel,
      router: NavigationControllerRouter(rootViewController: navigationController),
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    coordinator.didUpdateSendModel = { [weak self, weak coordinator, weak navigationController] sendModel in
      navigationController?.dismiss(animated: true, completion: {
        completion(sendModel)
      })
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didFinish = { [weak self, weak coordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.present(navigationController)
  }
  
  func openSendConfirmation(sendModel: SendModel) {
    guard let recipient = sendModel.recipient else { return }
    let module = SendConfirmationAssembly.module(
      sendConfirmationController: keeperCoreMainAssembly.sendConfirmationController(
        wallet: sendModel.wallet,
        recipient: recipient,
        sendItem: sendModel.sendItem,
        comment: sendModel.comment
      )
    )
    
    module.output.didSendTransaction = { [weak self] in
      NotificationCenter.default.post(Notification(name: Notification.Name("DID SEND TRANSACTION")))
      self?.router.dismiss(completion: {
        self?.didFinish?()
      })
    }
    
    module.output.didRequireSign = { [weak self] walletTransfer, wallet in
      guard let self = self else { return nil }
      let coordinator = await WalletTransferSignCoordinator(
        router: ViewControllerRouter(rootViewController: router.rootViewController),
        wallet: wallet,
        walletTransfer: walletTransfer,
        keeperCoreMainAssembly: keeperCoreMainAssembly)
      
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
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
  
  func openTokenPicker(wallet: Wallet, token: Token, sourceViewController: UIViewController, completion: @escaping (Token) -> Void) {
    let module = TokenPickerAssembly.module(
      tokenPickerController: keeperCoreMainAssembly.tokenPickerController(
        wallet: wallet,
        selectedToken: token
      )
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
//  
//  func handleExternalSign(url: URL, wallet: Wallet, fromViewController: UIViewController) async throws -> Data? {
//    return try await withCheckedThrowingContinuation { continuation in
//      DispatchQueue.main.async {
//        if self.coreAssembly.urlOpener().canOpen(url: url) {
//          self.externalSignHandler = { data in
//            continuation.resume(returning: data)
//          }
//          self.coreAssembly.urlOpener().open(url: url)
//        } else {
//          let module = SignerSignAssembly.module(
//            url: url,
//            wallet: wallet,
//            assembly: self.keeperCoreMainAssembly,
//            coreAssembly: self.coreAssembly
//          )
//          let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
//          
//          bottomSheetViewController.didClose = { isInteractivly in
//            guard isInteractivly else { return }
//            continuation.resume(returning: nil)
//          }
//          
//          module.output.didScanSignedTransaction = { [weak bottomSheetViewController] model in
//            bottomSheetViewController?.dismiss(completion: {
//              continuation.resume(returning: model.boc)
//            })
//          }
//          
//          bottomSheetViewController.present(fromViewController: fromViewController)
//        }
//      }
//    }
//  }
}
