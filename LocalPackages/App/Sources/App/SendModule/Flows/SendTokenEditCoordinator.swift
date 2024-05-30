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
  var didUpdateSendModel: ((SendModel) -> Void)?
  
  private weak var recipientModuleInput: SendRecipientModuleInput?
  private weak var amountModuleInput: SendAmountModuleInput?
  private weak var commentModuleInput: SendCommentModuleInput?
  
  private let flowViewController = SendEditFlowViewController()
  
  private var step: Step
  private var currentStep: Step
  
  private let sendModel: SendModel
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(step: Step,
       sendModel: SendModel,
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
    
    flowViewController.buttonsView.nextButton.configuration.action = { [weak self] in
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
    
    flowViewController.buttonsView.backButton.configuration.action = { [weak self] in
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
      switch sendModel.sendItem {
      case .token(let token, let amount):
        openAmount(
          recipient: sendModel.recipient,
          token: token,
          amount: amount
        )
      case .nft, .swap, .staking:
        break
      }
    case .comment:
      openComment(
        recipient: sendModel.recipient,
        sendItem: sendModel.sendItem,
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
      switch sendModel.sendItem {
      case .token(let token, let amount):
        self?.currentStep = .amount
        self?.openAmount(recipient: recipient, token: token, amount: amount)
      case .nft, .swap, .staking:
        self?.currentStep = .comment
        self?.openComment(
          recipient: recipient,
          sendItem: sendModel.sendItem,
          comment: sendModel.comment
        )
      }
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
    
    module.output.didTapTokenPicker = { [weak self] wallet, token in
      guard let self else { return }
      self.openTokenPicker(wallet: wallet, token: token, sourceViewController: router.rootViewController, completion: { token in
        module.input.setToken(token: token)
      })
    }
    
    module.output.didFinish = { [weak self, sendModel] token, amount in
      self?.currentStep = .comment
      self?.openComment(recipient: recipient,
                        sendItem: SendItem.token(token, amount: amount),
                        comment: sendModel.comment)
    }

    self.amountModuleInput = module.input
    
    flowViewController.flowNavigationController.pushViewController(module.view, animated: true)
  }
  
  func openComment(recipient: Recipient?, sendItem: SendItem, comment: String?) {
    let module = SendCommentAssembly.module(
      sendCommentController: keeperCoreMainAssembly.sendCommentController(
        isCommentRequired: recipient?.isMemoRequired ?? false,
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
        SendModel(
          wallet: sendModel.wallet,
          recipient: recipient,
          sendItem: sendItem,
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
