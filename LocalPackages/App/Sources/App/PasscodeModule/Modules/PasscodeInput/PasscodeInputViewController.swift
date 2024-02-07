import UIKit
import TKUIKit

public final class PasscodeInputViewController: GenericViewViewController<PasscodeInputView> {
  private let viewModel: PasscodeInputViewModel
  
  init(viewModel: PasscodeInputViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    setupActions()
    viewModel.viewDidLoad()
  }
  
  public override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    viewModel.viewDidDisappear()
  }
}

private extension PasscodeInputViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] model in
      customView.configure(model: model)
    }
    
    viewModel.didUpdatePasscodeInputState = { [customView] inputState in
      customView.passcodeView.inputState = inputState
      switch inputState {
      case .input(let count):
        customView.isUserInteractionEnabled = count < .dotsCount
      }
    }
    
    viewModel.didUpdatePasscodeValidationState = { [weak self, customView] validationState, completion in
      customView.passcodeView.validationState = validationState
      switch validationState {
      case .failed:
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          self?.removeDotRowInput {
            completion?()
          }
        }
      case .success:
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          completion?()
        }
      case .none: break
      }
    }
  }
  
  func setupActions() {
    customView.keyboardView.didTapDigit = { [viewModel] digit in
      viewModel.didTapDigit(digit)
    }
    
    customView.keyboardView.didTapBackspace = { [viewModel] in
      viewModel.didTapBackspace()
    }
    
    customView.keyboardView.didTapBiometry = { [viewModel] in
      viewModel.didTapBiometry()
    }
  }
  
  func removeDotRowInput(completion: @escaping () -> Void) {
    var count = Int.dotsCount
    Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
      self?.customView.passcodeView.inputState = .input(count: count)
      count -= 1
      if count < 0 {
        timer.invalidate()
        self?.customView.passcodeView.validationState = .none
        completion()
      }
    }
  }
}

private extension Int {
  static let dotsCount = 4
}
