import Foundation
import TKUIKit

protocol WalletBalanceModuleOutput: AnyObject {
  
}

protocol WalletBalanceViewModel: AnyObject {
  func viewDidLoad()
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput {
  
  // MARK: - WalletBalanceModuleOutput
  
  // MARK: - WalletBalanceViewModel
  
  func viewDidLoad() {
    
  }
}
