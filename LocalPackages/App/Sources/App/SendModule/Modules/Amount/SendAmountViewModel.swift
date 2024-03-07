import UIKit
import KeeperCore
import BigInt

protocol SendAmountModuleOutput: AnyObject {
  var didUpdateIsContinueEnable: ((Bool) -> Void)? { get set }
  var didFinish: ((Token, BigUInt) -> Void)? { get set }
  var didTapTokenPicker: ((Wallet, Token) -> Void)? { get set }
}

protocol SendAmountModuleInput: AnyObject {
  func finish()
  func setToken(token: Token)
}

protocol SendAmountViewModel: AnyObject {
  
  var didUpdateConvertedValue: ((String) -> Void)? { get set }
  var didUpdateInputValue: ((String?) -> Void)? { get set }
  var didUpdateInputSymbol: ((String?) -> Void)? { get set }
  var didUpdateMaximumFractionDigits: ((Int) -> Void)? { get set }
  var didUpdateIsTokenPickerAvailable: ((Bool) -> Void)? { get set }
  var didUpdateRemaining: ((NSAttributedString) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
  func didEditInput(_ input: String?)
  func toggleInputMode()
  func toggleMax()
  func didTapTokenPickerButton()
}

final class SendAmountViewModelImplementation: SendAmountViewModel, SendAmountModuleOutput, SendAmountModuleInput {
  
  // MARK: - SendAmountModuleOutput
  
  var didUpdateIsContinueEnable: ((Bool) -> Void)?
  var didFinish: ((Token, BigUInt) -> Void)?
  var didTapTokenPicker: ((Wallet, Token) -> Void)?
  
  // MARK: - SendAmountModuleInput
  
  func finish() {
    didFinish?(sendAmountController.getToken(), sendAmountController.getTokenAmount())
  }
  
  func setToken(token: Token) {
    sendAmountController.setToken(token)
  }
  
  // MARK: - SendAmountViewModel
  
  var didUpdateConvertedValue: ((String) -> Void)?
  var didUpdateInputValue: ((String?) -> Void)?
  var didUpdateInputSymbol: ((String?) -> Void)?
  var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  var didUpdateIsTokenPickerAvailable: ((Bool) -> Void)?
  var didUpdateRemaining: ((NSAttributedString) -> Void)?
  
  func viewDidLoad() {
    sendAmountController.didUpdateConvertedValue = { [weak self] value in
      self?.didUpdateConvertedValue?(value)
    }
    
    sendAmountController.didUpdateInputValue = { [weak self] value in
      self?.didUpdateInputValue?(value)
    }
    
    sendAmountController.didUpdateInputSymbol = { [weak self] symbol in
      self?.didUpdateInputSymbol?(symbol)
    }
    
    sendAmountController.didUpdateMaximumFractionDigits = { [weak self] fractionDigits in
      self?.didUpdateMaximumFractionDigits?(fractionDigits)
    }
    
    sendAmountController.didUpdateIsTokenPickerAvailable = { [weak self] in
      self?.didUpdateIsTokenPickerAvailable?($0)
    }
    
    sendAmountController.didUpdateIsContinueEnabled = { [weak self] in
      self?.isContinueEnabled = $0
    }
    
    sendAmountController.didUpdateRemaining = { [weak self] remaining in
      switch remaining {
      case .remaining(let value):
        self?.didUpdateRemaining?(
          value.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
          )
        )
      case .insufficient:
        self?.didUpdateRemaining?(
          "Insufficient balance".withTextStyle(
            .body2,
            color: .Accent.red,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
          )
        )
      }
    }
    
    sendAmountController.start()
  }
  
  func viewDidAppear() {
    didUpdateIsContinueEnable?(isContinueEnabled)
  }
  
  func viewWillDisappear() {
    didUpdateIsContinueEnable?(isContinueEnabled)
  }
  
  func didEditInput(_ input: String?) {
    sendAmountController.setInput(input ?? "")
  }
  
  func toggleInputMode() {
    sendAmountController.toggleMode()
  }
  
  func toggleMax() {
    sendAmountController.toggleMax()
  }
  
  func didTapTokenPickerButton() {
    didTapTokenPicker?(sendAmountController.wallet, sendAmountController.token)
  }
  
  // MARK: - State
  
  private var isContinueEnabled: Bool = false {
    didSet {
      didUpdateIsContinueEnable?(isContinueEnabled)
    }
  }
  
  // MARK: - Dependencies
  
  private let sendAmountController: SendAmountController
  
  // MARK: - Init
  
  init(sendAmountController: SendAmountController) {
    self.sendAmountController = sendAmountController
  }
}
