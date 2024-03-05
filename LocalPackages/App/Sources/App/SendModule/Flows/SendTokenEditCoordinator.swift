import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore
import BigInt

final class SendTokenEditCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  enum Step {
    case recipient
    case amount
    case comment
  }
  
  var didFinish: (() -> Void)?
  var didUpdateSendModel: ((SendTokenModel) -> Void)?
  
  private weak var recipientModuleInput: SendRecipientModuleInput?
  private weak var amountModuleInput: SendAmountModuleInput?
  private weak var commentModuleInput: SendCommentModuleInput?
  
  private let flowViewController = SendEditFlowViewController()
  
  private var step: Step
  private var currentStep: Step
  
  private let sendModel: SendTokenModel
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(step: Step,
       sendModel: SendTokenModel,
       router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.step = step
    self.currentStep = step
    self.sendModel = sendModel
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }
  
  public override func start() {
    flowViewController.flowNavigationController.configureDefaultAppearance()
    router.push(viewController: flowViewController)
    
    openFirst()
    
    flowViewController.buttonsView.nextButton.setTapAction { [weak self] in
      guard let self else { return }
      switch self.currentStep {
      case .recipient:
        self.recipientModuleInput?.finish()
      case .amount:
        self.amountModuleInput?.finish()
      case .comment:
        self.commentModuleInput?.finish()
      }
    }
    
    flowViewController.buttonsView.backButton.setTapAction { [weak self] in
      guard let self else { return }
      guard currentStep != step else {
        self.didFinish?()
        return
      }
      switch self.currentStep {
      case .recipient:
        self.didFinish?()
      case .amount:
        self.currentStep = .recipient
        self.flowViewController.flowNavigationController.popViewController(animated: true)
      case .comment:
        self.currentStep = .amount
        self.flowViewController.flowNavigationController.popViewController(animated: true)
      }
    }
  }
}

private extension SendTokenEditCoordinator {
  func openFirst() {
    switch step {
    case .recipient:
      openRecipient(recipient: sendModel.recipient)
    case .amount:
      openAmount(
        recipient: sendModel.recipient,
        token: sendModel.token,
        amount: sendModel.amount
      )
    case .comment:
      openComment(
        recipient: sendModel.recipient,
        token: sendModel.token,
        amount: sendModel.amount,
        comment: sendModel.comment
      )
    }
  }
  
  func openRecipient(recipient: Recipient?) {
    let module = SendRecipientAssembly.module(
      sendRecipientController: keeperCoreMainAssembly.sendRecipientController(
        recipient: recipient
      )
    )

    module.view.setupLeftCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didUpdateIsNextAvailable = { [weak self] isAvailable in
      self?.flowViewController.buttonsView.nextButton.isEnabled = isAvailable
    }

    module.output.didFinish = { [weak self, sendModel] recipient in
      self?.currentStep = .amount
      self?.openAmount(recipient: recipient, token: sendModel.token, amount: sendModel.amount)
    }
    
    recipientModuleInput = module.input
    
    flowViewController.flowNavigationController.pushViewController(module.view, animated: true)
  }
  
  func openAmount(recipient: Recipient?, token: Token, amount: BigUInt) {
    let module = SendAmountAssembly.module(
      sendAmountController: keeperCoreMainAssembly.sendAmountController(
        token: token,
        tokenAmount: amount,
        wallet: sendModel.wallet
      )
    )
    
    module.view.setupLeftCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didUpdateIsContinueEnable = { [weak self] isEnable in
      self?.flowViewController.setIsNextAvailable(isEnable)
    }
    
    module.output.didFinish = { [weak self, sendModel] token, amount in
      self?.currentStep = .comment
      self?.openComment(recipient: recipient, token: token, amount: amount, comment: sendModel.comment)
    }

    self.amountModuleInput = module.input
    
    flowViewController.flowNavigationController.pushViewController(module.view, animated: true)
  }
  
  func openComment(recipient: Recipient?, token: Token, amount: BigUInt, comment: String?) {
    let module = SendCommentAssembly.module(
      sendCommentController: keeperCoreMainAssembly.sendCommentController(
        isCommentRequired: recipient?.isKnownAccount ?? false,
        comment: comment
      )
    )
    
    module.view.setupLeftCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didUpdateIsContinueEnable = { [weak self] isEnable in
      self?.flowViewController.setIsNextAvailable(isEnable)
    }
    
    module.output.didFinish = { [weak self, sendModel] in
      self?.didUpdateSendModel?(
        SendTokenModel(
          wallet: sendModel.wallet,
          recipient: recipient,
          amount: amount,
          token: token,
          comment: $0
        )
      )
    }
    
    self.commentModuleInput = module.input

    flowViewController.flowNavigationController.pushViewController(module.view, animated: true)
  }
  
  func handleBack() {
    if router.rootViewController.viewControllers.count > 1 {
      router.rootViewController.popViewController(animated: true)
    } else {
      didFinish?()
    }
  }
}
