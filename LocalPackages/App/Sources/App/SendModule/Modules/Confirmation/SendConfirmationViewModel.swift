import UIKit
import KeeperCore

protocol SendConfirmationModuleOutput: AnyObject {
  
}

protocol SendConfirmationModuleInput: AnyObject {
  
}

protocol SendConfirmationViewModel: AnyObject {
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
}

final class SendConfirmationViewModelImplementation: SendConfirmationViewModel, SendConfirmationModuleOutput, SendConfirmationModuleInput {
  
  // MARK: - SendConfirmationModuleOutput
  
  // MARK: - SendConfirmationModuleInput
  
  // MARK: - SendConfirmationViewModel
  
  func viewDidLoad() {
  }
  
  func viewDidAppear() {
    
  }
  
  func viewWillDisappear() {
    
  }
  
  // MARK: - Dependencies
  
  private let sendConfirmationController: SendConfirmationController
  
  // MARK: - Init
  
  init(sendConfirmationController: SendConfirmationController) {
    self.sendConfirmationController = sendConfirmationController
  }
}

private extension SendConfirmationViewModelImplementation {}
