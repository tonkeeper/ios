import Foundation

protocol LedgerConnectModuleOutput: AnyObject {}

protocol LedgerConnectViewModel: AnyObject {
  func viewDidLoad()
}

final class LedgerConnectViewModelImplementation: LedgerConnectViewModel, LedgerConnectModuleOutput {
  
  // MARK: - LedgerConnectModuleOutput
  
  // MARK: - LedgerConnectViewModel
  
  func viewDidLoad() {
    
  }
  
  // MARK: - Dependencies
  
  // MARK: - Init
}
