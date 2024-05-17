import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

protocol StakingModuleOutput: AnyObject {
  var didTapContinue: ((Wallet) -> Void)? { get set }
  var didTapProviderPicker: (() -> Void)? { get set }
}

protocol StakingModuleInput: AnyObject {
  func setOption(_ item: OptionItem)
}

protocol StakingViewModel: AnyObject {
  var didUpdateConvertedValue: ((String) -> Void)? { get set }
  var didUpdateInputValue: ((String?) -> Void)? { get set }
  var didUpdateInputSymbol: ((String?) -> Void)? { get set }
  var didUpdateMaximumFractionDigits: ((Int) -> Void)? { get set }
  var didUpdateRemaining: ((NSAttributedString) -> Void)? { get set }
  var didUpdateProvider: ((StakingProviderView.Model) -> Void)? { get set }
  var didUpdateIsContinueEnabled: ((Bool) -> Void)? { get set }
  var didUpdateSwapIcon: ((Bool) -> Void)? { get set }
  var didResetHighlightIsMax: (() -> Void)? { get set }
  
  func viewDidLoad()
  func didEditAmountInput(_ string: String?)
  func didToggleMaxAmount()
  func didTapProvider()
  func didToggleInputMode()
  func didTapContinueButton()
}

final class StakingViewModelImplementation: StakingViewModel, StakingModuleOutput, StakingModuleInput {
  
  // MARK: - StakingModuleInput
  
  func setOption(_ item: OptionItem) {
    controller.setProvider(item)
  }
  
  // MARK: - StakingModuleOutput
  
  var didTapContinue: ((Wallet) -> Void)?
  var didTapProviderPicker: (() -> Void)?
  
  // MARK: - StakingViewModel
  var didUpdateConvertedValue: ((String) -> Void)?
  var didUpdateInputValue: ((String?) -> Void)?
  var didUpdateInputSymbol: ((String?) -> Void)?
  var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  var didUpdateRemaining: ((NSAttributedString) -> Void)?
  var didUpdateProvider: ((StakingProviderView.Model) -> Void)?
  var didUpdateSwapIcon: ((Bool) -> Void)?
  var didUpdateIsContinueEnabled: ((Bool) -> Void)?
  var didResetHighlightIsMax: (() -> Void)?
  
  func viewDidLoad() {
    setupControllerBindinds()
    
    controller.start()
  }

  func didToggleMaxAmount() {
    controller.toggleMax()
  }
  
  func didEditAmountInput(_ string: String?) {
    controller.setInput(string ?? "")
  }
  
  func didToggleInputMode() {
    controller.toggleMode()
  }
  
  func didTapProvider() {
    didTapProviderPicker?()
  }
  
  func didTapContinueButton() {
    let wallet = controller.getActiveActiveWallet()
    
    didTapContinue?(wallet)
  }
  
  // MARK: - Dependencies
  
  private let controller: StakingController
  private let itemMapper: StakingItemMapper = .init()
  
  init(controller: StakingController) {
    self.controller = controller
  }
}

// MARK: - Private methods
private extension StakingViewModelImplementation {
  func setupControllerBindinds() {
    controller.didUpdateConvertedValue = { [weak self] value in
      self?.didUpdateConvertedValue?(value)
    }
    
    controller.didUpdateInputValue = { [weak self] value in
      self?.didUpdateInputValue?(value)
    }
    
    controller.didUpdateInputSymbol = { [weak self] symbol in
      self?.didUpdateInputSymbol?(symbol)
    }
    
    controller.didUpdateMaximumFractionDigits = { [weak self] fractionDigits in
      self?.didUpdateMaximumFractionDigits?(fractionDigits)
    }
    
    controller.didUpdateIsContinueEnabled = { [weak self] in
      self?.didUpdateIsContinueEnabled?($0)
    }
    
    controller.didUpdateRemaining = { [weak self] remaining in
      guard let self else { return }
      
      let value = self.makeRemainingValue(remaining)
      self.didUpdateRemaining?(value)
    }
    
    controller.didUpdateIsHiddenSwapIcon = { [weak self] isHidden in
      self?.didUpdateSwapIcon?(isHidden)
    }
    
    controller.didResetMax = { [weak self] in
      self?.didResetHighlightIsMax?()
    }
    
    controller.didUpdateProvider = { [weak self]  in
      guard let self else { return }
  
      self.didUpdateProvider?(self.itemMapper.mapOptionItem($0))
    }
  }
  
  func makeRemainingValue(_ remaining: StakingController.Remaining) -> NSAttributedString {
    switch remaining {
    case .remaining(let value):
      return "\(String.remainingPrefix) \(value)".withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
    case .insufficient:
      return String.insufficientPrefix.withTextStyle(
          .body2,
          color: .Accent.red,
          alignment: .right,
          lineBreakMode: .byTruncatingTail
        )
    }
  }
}

private extension String {
  static let remainingPrefix = "Remaining:"
  static let insufficientPrefix = "Insufficient balance"
}
