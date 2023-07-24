//
//  PasscodeInputPasscodeInputViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 29/06/2023.
//

import UIKit

class PasscodeInputViewController: GenericViewController<PasscodeInputView> {
  
  // MARK: - Module
  
  private let presenter: PasscodeInputPresenterInput
  
  // MARK: - Init
  
  init(presenter: PasscodeInputPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    presenter.viewDidDisappear()
  }
}

// MARK: - PasscodeInputViewInput

extension PasscodeInputViewController: PasscodeInputViewInput {
  func updateDotRow(with inputState: PasscodeDotRowView.InputState,
                    validationState: PasscodeDotRowView.ValidationState) {
    customView.dotRowView.inputState = inputState
    customView.dotRowView.validationState = validationState
  }
  
  func updateTitle(_ title: String) {
    customView.titleLabel.text = title
  }
  
  func updateBiometryAvailability(_ isAvailable: Bool) {
    isAvailable ? customView.showBiometryButton() : customView.hideBiometryButton()
  }
  
  func handlePinInputFailed() {
    shakeDotRow()
    removeDotRowInput()
  }
  
  func handlePinInputSuccess() {
    TapticGenerator.generateSuccessFeedback()
    scaleDots { [weak self] in
      self?.presenter.didHandleInputSuccess()
    }
  }
  
  func handleDigitInput(at index: Int) {
    scaleDot(at: index)
  }
  
  func didEnterPin() {
    customView.isUserInteractionEnabled = false
  }
  
  func didResetPin() {
    customView.isUserInteractionEnabled = true
  }
}

extension PasscodeInputViewController: TKKeyboardViewDelegate, TKKeyboardViewBiometryDelegate {
  func keyboard(_ keyboard: TKKeyboardView, didTapDigit digit: Int) {
    presenter.didTapDigitButton(digit: digit)
  }
  
  func keyboardDidTapBackspace(_ keyboard: TKKeyboardView) {
    presenter.didTapBackspaceButton()
  }
  
  func keyboardDidTapBiometry(_ keyboard: TKKeyboardView) {
    presenter.didTapBiometryButton()
  }
}

// MARK: - Private

private extension PasscodeInputViewController {
  func setup() {
    customView.keyboardView.delegate = self
  }
  
  func shakeDotRow() {
    let animation = CABasicAnimation(keyPath: "position")
    animation.duration = .dotsShakeAnimationDuration
    animation.repeatCount = .dotsShakeAnimationRepeatCount
    animation.autoreverses = true
    animation.fromValue = NSValue(cgPoint: CGPoint(x: customView.dotRowView.center.x - .dotsShakeAnimationPositionDiff, y: customView.dotRowView.center.y))
    animation.toValue = NSValue(cgPoint: CGPoint(x: customView.dotRowView.center.x + .dotsShakeAnimationPositionDiff, y: customView.dotRowView.center.y))
    customView.dotRowView.layer.add(animation, forKey: "position")
  }
  
  func removeDotRowInput() {
    var count = CGFloat.dotsCount
    Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
      self?.customView.dotRowView.inputState = .input(count: count)
      count -= 1
      if count < 0 {
        timer.invalidate()
        self?.customView.dotRowView.validationState = .none
        self?.presenter.didHandleInputFailed()
      }
    }
  }
  
  func scaleDot(at index: Int) {
    customView.dotRowView.dots[index].layer.add(scaleAnimation(), forKey: nil)
  }
  
  func scaleDots(completion: @escaping () -> Void) {
    CATransaction.begin()
    CATransaction.setCompletionBlock {
      completion()
    }
    customView.dotRowView.dots
      .enumerated()
      .map { $0.offset }
      .forEach { scaleDot(at: $0) }
    CATransaction.commit()
  }
  
  func scaleAnimation() -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "transform.scale")
    animation.fromValue = 1
    animation.toValue = 1.5
    animation.duration = 0.1
    animation.autoreverses = true
    return animation
  }
}

private extension CGFloat {
  static let dotsCount = 4
  static let dotsShakeAnimationPositionDiff: CGFloat = 10
}

private extension TimeInterval {
  static let dotsShakeAnimationDuration: TimeInterval = 0.07
}

private extension Float {
  static let dotsShakeAnimationRepeatCount: Float = 3
}
