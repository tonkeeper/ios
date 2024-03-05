import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore

final class SendTokenCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let token: Token
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       token: Token) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.token = token
    super.init(router: router)
  }
  
  public override func start() {
    openSend()
  }
}

private extension SendTokenCoordinator {
  func openSend() {
    let module = SendAssembly.module(sendController: keeperCoreMainAssembly.sendController(token: token))
    
    module.output.didTapRecipientItemButton = { [weak self, weak input = module.input] sendModel in
      self?.openRecipientInput(sendModel: sendModel,
                               completion: { sendModel in
        input?.updateWithSendModel(sendModel)
      })
    }
    
    module.output.didTapAmountInputButton = { [weak self, weak input = module.input] sendModel in
      self?.openAmountInput(sendModel: sendModel,
                               completion: { sendModel in
        input?.updateWithSendModel(sendModel)
      })
    }
    
    module.output.didTapCommentInputButton = { [weak self, weak input = module.input] sendModel in
      self?.openCommentInput(sendModel: sendModel,
                               completion: { sendModel in
        input?.updateWithSendModel(sendModel)
      })
    }
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openRecipientInput(sendModel: SendTokenModel,
                          completion: @escaping (SendTokenModel) -> Void) {
    openSendTokenEdit(sendModel: sendModel, step: .recipient, completion: completion)
  }
  
  func openAmountInput(sendModel: SendTokenModel,
                       completion: @escaping (SendTokenModel) -> Void) {
    openSendTokenEdit(sendModel: sendModel, step: .amount, completion: completion)
  }
  
  func openCommentInput(sendModel: SendTokenModel,
                        completion: @escaping (SendTokenModel) -> Void) {
    openSendTokenEdit(sendModel: sendModel, step: .comment, completion: completion)
  }
  
  func openSendTokenEdit(sendModel: SendTokenModel, 
                         step: SendTokenEditCoordinator.Step,
                         completion: @escaping (SendTokenModel) -> Void) {
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
}
