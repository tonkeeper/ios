import UIKit
import TKUIKit
import SnapKit

final class PasscodeInputView: UIView {
  
  enum State {
    case input(Int)
    case failed(Int)
    case success
  }
  
  var title: String? {
    didSet {
      titleLabel.attributedText = title?.withTextStyle(
        .h3,
        color: .Text.primary
      )
    }
  }
  
  let passcodeView = PasscodeDotRowView()
  let titleLabel = UILabel()
  let topContainer = UIView()
  let stackView = UIStackView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setState(_ state: State, completion: (() -> Void)?) {
    passcodeView.layer.removeAllAnimations()
    switch state {
    case .input(let count):
      passcodeView.inputCount = count
      passcodeView.validationState = .none
      completion?()
    case .failed(let count):
      passcodeView.validationState = .failed
      shakeDots { [weak self] in
        self?.reset(inputCount: count, completion: completion)
      }
    case .success:
      passcodeView.validationState = .success
      completion?()
    }
  }
  
  private func reset(inputCount: Int, completion: (() -> Void)?) {
    var count = inputCount
    Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
      count -= 1
      self?.passcodeView.inputCount = count
      self?.passcodeView.validationState = .failed
      if count < 0 {
        timer.invalidate()
        completion?()
      }
    }
  }
  
  private func shakeDots(completion: @escaping () -> Void) {
    let passcodeViewCenter = passcodeView.center
    let animation = CABasicAnimation(keyPath: "position")
    animation.duration = .dotsShakeAnimationDuration
    animation.repeatCount = .dotsShakeAnimationRepeatCount
    animation.autoreverses = true
    animation.fromValue = NSValue(
      cgPoint: CGPoint(
        x: passcodeViewCenter.x - .dotsShakeAnimationPositionDiff,
        y: passcodeViewCenter.y
      )
    )
    animation.toValue = NSValue(
      cgPoint: CGPoint(
        x: passcodeViewCenter.x + .dotsShakeAnimationPositionDiff,
        y: passcodeViewCenter.y
      )
    )
    CATransaction.setCompletionBlock {
      completion()
    }
    
    passcodeView.layer.add(animation, forKey: nil)
    CATransaction.commit()
  }
}

private extension PasscodeInputView {
  func setup() {
    backgroundColor = .Background.page
    
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.spacing = .titleBottomSpace
    
    addSubview(topContainer)
    topContainer.addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(passcodeView)
    
    setupConstraints()
  }

  func setupConstraints() {
    topContainer.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide)
      make.left.bottom.right.equalTo(self)
      
      stackView.snp.makeConstraints { make in
        make.center.equalTo(topContainer)
      }
    }
  }
}

private extension CGFloat {
  static let titleBottomSpace: CGFloat = 20
  static let dotsShakeAnimationPositionDiff: CGFloat = 10
}

private extension TimeInterval {
  static let dotsShakeAnimationDuration: TimeInterval = 0.07
}

private extension Float {
  static let dotsShakeAnimationRepeatCount: Float = 3
}
