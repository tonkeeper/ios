import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore

final class SendTokenCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
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
    
    module.output.didRequireConfirmation = { [weak self] in
      guard let self else { return false }
      return await self.openConfirmation(fromViewController: self.router.rootViewController)
    }
    
    module.output.didSendTransaction = { [weak self] in
      self?.router.dismiss(completion: {
        self?.didFinish?()
      })
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
  
  func openConfirmation(fromViewController: UIViewController) async -> Bool {
    return await Task<Bool, Never> { @MainActor in
      return await withCheckedContinuation { [weak self, keeperCoreMainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
        guard let self = self else { return }
        let coordinator = PasscodeModule(
          dependencies: PasscodeModule.Dependencies(
            passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
          )
        ).passcodeConfirmationCoordinator()
        
        coordinator.didCancel = { [weak self, weak coordinator] in
          continuation.resume(returning: false)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        coordinator.didConfirm = { [weak self, weak coordinator] in
          continuation.resume(returning: true)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        self.addChild(coordinator)
        coordinator.start()
        
        fromViewController.present(coordinator.router.rootViewController, animated: true)
      }
    }.value
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
}
