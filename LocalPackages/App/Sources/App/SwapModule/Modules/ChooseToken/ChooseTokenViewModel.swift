import Foundation
import KeeperCore
import TKUIKit
import TKCore

protocol ChooseTokenModuleOutput: AnyObject {
  var didFinish: (() -> Void)? { get set }
  var didSelectToken: ((Token) -> Void)? { get set }
}

protocol ChooseTokenViewModel: AnyObject {
  var didUpdateTokens: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  func viewDidLoad()
}

final class ChooseTokenViewModelImplementation: ChooseTokenViewModel, ChooseTokenModuleOutput {
  
  // MARK: - TokenPickerModuleOutput
  
  var didFinish: (() -> Void)?
  var didSelectToken: ((Token) -> Void)?
  var didUpdateTokens: (([TKUIListItemCell.Configuration]) -> Void)?
  
  // MARK: - TokenPickerViewModel
  
  func viewDidLoad() {
    var items = [TKUIListItemCell.Configuration]()
    for _ in 0..<10 {
      items.append(ChooseTokenListItemMapper().make())
    }
    didUpdateTokens?(items)
  }
  
  // MARK: - Image Loading
    
  // MARK: - Dependencies
    
  // MARK: - Init
  
  init() {
  }
}

private extension ChooseTokenViewModelImplementation { }
