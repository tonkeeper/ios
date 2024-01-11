import Foundation
import TKUIKit

protocol CollectiblesModuleOutput: AnyObject {
  
}

protocol CollectiblesViewModel: AnyObject {
  func viewDidLoad()
}

final class CollectiblesViewModelImplementation: CollectiblesViewModel, CollectiblesModuleOutput {
  
  // MARK: - CollectiblesModuleOutput
  
  // MARK: - CollectiblesViewModel
  
  func viewDidLoad() {
    
  }
}
