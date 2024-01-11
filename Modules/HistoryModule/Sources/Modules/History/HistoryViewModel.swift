import Foundation
import TKUIKit

protocol HistoryModuleOutput: AnyObject {
  
}

protocol HistoryViewModel: AnyObject {
  func viewDidLoad()
}

final class HistoryViewModelImplementation: HistoryViewModel, HistoryModuleOutput {
  
  // MARK: - HistoryModuleOutput
  
  // MARK: - HistoryViewModel
  
  func viewDidLoad() {
    
  }
}
