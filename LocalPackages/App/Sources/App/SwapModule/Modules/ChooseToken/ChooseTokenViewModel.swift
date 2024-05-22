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
    Task {
      let availableTokens = await swapAvailableTokenController.receiveTokenList()
      let mapper = ChooseTokenListItemMapper()
      let items = availableTokens.map { mapper.mapAvailabeToken($0) }
      await MainActor.run {
        didUpdateTokens?(items)
      }
    }
  }
  
  // MARK: - Image Loading
    
  // MARK: - Dependencies

  private let swapAvailableTokenController: SwapAvailableTokenController
    
  // MARK: - Init
  
  init(swapAvailableTokenController: SwapAvailableTokenController) {
    self.swapAvailableTokenController = swapAvailableTokenController
  }
}

private extension ChooseTokenViewModelImplementation { }
