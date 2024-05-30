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
      let availableTokens = await swapAvailableTokenController.receiveTokenList(exclude: excludeToken)
      let mapper = ChooseTokenListItemMapper()
      let items = availableTokens.map { availableToken in
        mapper.mapAvailabeToken(availableToken, selectionClosure:  { [weak self] in
          self?.didSelectToken?(availableToken.token)
        })
      }
      await MainActor.run {
        didUpdateTokens?(items)
      }
    }
  }
  
  // MARK: - Image Loading
    
  // MARK: - Dependencies

  private let swapAvailableTokenController: SwapAvailableTokenController
  private let excludeToken: Token?
    
  // MARK: - Init
  
  init(excludeToken: Token?, swapAvailableTokenController: SwapAvailableTokenController) {
    self.swapAvailableTokenController = swapAvailableTokenController
    self.excludeToken = excludeToken
  }
}

private extension ChooseTokenViewModelImplementation { }
