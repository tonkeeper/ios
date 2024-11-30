import Foundation

@MainActor
protocol SignRawConfirmationModuleOutput: AnyObject {}

@MainActor
protocol SignRawConfirmationViewModel: AnyObject {
  func viewDidLoad()
}

@MainActor
final class SignRawConfirmationViewModelImplementation: SignRawConfirmationViewModel, SignRawConfirmationModuleOutput {
  
  // MARK: - SignRawConfirmationModuleOutput
  
  // MARK: - SignRawConfirmationViewModel
  
  func viewDidLoad() {
    
  }
}
