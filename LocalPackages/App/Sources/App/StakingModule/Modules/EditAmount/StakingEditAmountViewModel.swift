import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

protocol StakingEditAmountModuleOutput: AnyObject {
  var didTapContinue: ((StakingConfirmationItem) -> Void)? { get set }
  var didTapPoolPicker: ((StakingOptionsListModel, Address?) -> Void)? { get set }
  var didTapBuy: ((Wallet) -> Void)? { get set }
}

protocol StakingEditAmountModuleInput: AnyObject {
  func setStakingPool(_ pool: StakingPool)
}

protocol StakingEditAmountViewModel: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateConvertedValue: ((String) -> Void)? { get set }
  var didUpdateInputValue: ((String?) -> Void)? { get set }
  var didUpdateInputSymbol: ((String?) -> Void)? { get set }
  var didUpdateMaximumFractionDigits: ((Int) -> Void)? { get set }
  var didUpdateRemaining: ((NSAttributedString) -> Void)? { get set }
  var didUpdateProviderInfo: ((StakingProviderView.Model) -> Void)? { get set }
  var didUpdateSwapIcon: ((Bool) -> Void)? { get set }
  var didResetHighlightIsMax: (() -> Void)? { get set }
  var didUpdatePrimaryButton:((String, Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func didEditAmountInput(_ string: String?)
  func didToggleMaxAmount()
  func didTapPool()
  func didToggleInputMode()
  func didTapPrimaryButton()
}

final class StakingEditAmountViewModelImplementation: StakingEditAmountViewModel, StakingEditAmountModuleOutput, StakingEditAmountModuleInput {
  
  struct PrimaryButtonModel {
    let title: String
    let isEnable: String
  }
  
  // MARK: - StakingModuleInput
  
  func setStakingPool(_ pool: StakingPool) {
    controller.setStakingPool(pool)
  }
  
  // MARK: - StakingModuleOutput
  
  var didTapContinue: ((StakingConfirmationItem) -> Void)?
  var didTapPoolPicker: ((StakingOptionsListModel, Address?) -> Void)?
  var didTapBuy: ((Wallet) -> Void)?
  
  // MARK: - StakingViewModel
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateConvertedValue: ((String) -> Void)?
  var didUpdateInputValue: ((String?) -> Void)?
  var didUpdateInputSymbol: ((String?) -> Void)?
  var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  var didUpdateRemaining: ((NSAttributedString) -> Void)?
  var didUpdateProviderInfo: ((StakingProviderView.Model) -> Void)?
  var didUpdateSwapIcon: ((Bool) -> Void)?
  var didResetHighlightIsMax: (() -> Void)?
  var didUpdatePrimaryButton: ((String, Bool) -> Void)?
  
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
  
  func didTapPool() {
    guard let optionsListModel = controller.getOptionsListModel() else {
      return
    }
    
    didTapPoolPicker?(optionsListModel, controller.stakingPool.address)
  }
  
  func didTapPrimaryButton() {
    switch controller.primaryAction.action {
    case .buy:
      didTapBuy?(controller.wallet)
    case .confirm:
      let item = controller.getStakeConfirmationItem()
      didTapContinue?(item)
    }
  }
  
  // MARK: - Dependencies
  
  private let controller: StakingEditAmountController
  private let itemMapper: StakingEditAmountItemMapper
  
  init(controller: StakingEditAmountController, itemMapper: StakingEditAmountItemMapper) {
    self.controller = controller
    self.itemMapper = itemMapper
  }
}

// MARK: - Private methods
private extension StakingEditAmountViewModelImplementation {
  func setupControllerBindinds() {
    controller.didUpdateTitle = { [weak self] title in
      self?.didUpdateTitle?(title)
    }
    
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
    
    controller.didUpdatePrimaryAction = { [weak self] action in
      let title: String = action.action == .buy ? .primaryActionBuy : .primaryActionContinue
      self?.didUpdatePrimaryButton?(title, action.isEnable)
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
    
    controller.didUpdateProviderModel = { [weak self] model in
      guard let self else { return }
      
      switch model {
      case .pool(let item):
        let configuration = self.itemMapper.mapStakingPoolItem(item)
        self.didUpdateProviderInfo?(.listItem(configuration))
      case .validationCycleEnding(let remainingTime):
        let text = "\(String.validationCycleInfoPrefix) \(remainingTime)"
          .withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left
          )
        self.didUpdateProviderInfo?(.text(text))
      }
    }
  }
  
  func makeRemainingValue(_ remaining: StakingRemaining) -> NSAttributedString {
    switch remaining {
    case .remaining(let value):
      return "\(String.remainingPrefix) \(value)".withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
    case .lessThenMinDeposit(let minDepoAmount):
      return "\(String.minPrefix) \(minDepoAmount)".withTextStyle(
        .body2,
        color: .Accent.red,
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
  static let minPrefix = "Minimum"
  static let primaryActionBuy = "Buy"
  static let primaryActionContinue = "Continue"
  
  static let validationCycleInfoPrefix = "Unstake request will be processed after the end of the validation cycle in"
}
