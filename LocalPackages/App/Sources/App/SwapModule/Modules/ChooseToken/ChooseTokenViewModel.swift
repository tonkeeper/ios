import Foundation
import KeeperCore
import TKUIKit
import TKCore

protocol ChooseTokenModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didSelectToken: ((Token) -> Void)? { get set }
}

protocol ChooseTokenViewModel: AnyObject {  
  func viewDidLoad()
}

final class ChooseTokenViewModelImplementation: ChooseTokenViewModel, ChooseTokenModuleOutput {
  
  // MARK: - TokenPickerModuleOutput
  
  var didFinish: (() -> Void)?
  var didSelectToken: ((Token) -> Void)?
  
  // MARK: - TokenPickerViewModel
  
  func viewDidLoad() { }
  
  // MARK: - Image Loading
    
  // MARK: - Dependencies
    
  // MARK: - Init
  
  init() {
  }
}

private extension ChooseTokenViewModelImplementation { }
