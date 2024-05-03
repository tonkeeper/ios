import UIKit
import TKUIKit

final class PasswordInputView: UIView {
  
  let titleDescriptionView: TKTitleDescriptionView = {
    let view = TKTitleDescriptionView(size: .big)
    view.padding.bottom = .titleBottomPadding
    return view
  }()

  let passwordTextField = TKPasswordTextField()
  let passwordTextFieldContainer = TKPaddingContainerView()
  
  let continueButton = TKButton()
  let continueButtonContainer = TKPaddingContainerView()
  
  private var continueButtonContainerBottomSafeAreaConstraint: NSLayoutConstraint?
  private var continueButtonContainerBottomConstraint: NSLayoutConstraint?
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Keyboard
  
  func updateKeyboardHeight(_ height: CGFloat,
                            duration: TimeInterval,
                            curve: UIView.AnimationCurve) {
    continueButtonContainerBottomSafeAreaConstraint?.isActive = false
    continueButtonContainerBottomConstraint?.isActive = true
    continueButtonContainerBottomConstraint?.constant = -height
  }
  
  func hideKeyboard(duration: TimeInterval,
                    curve: UIView.AnimationCurve) {
    continueButtonContainerBottomConstraint?.isActive = false
    continueButtonContainerBottomConstraint?.constant = 0
    continueButtonContainerBottomSafeAreaConstraint?.isActive = true
  }
}

private extension PasswordInputView {
  func setup() {
    backgroundColor = .Background.page
    
    directionalLayoutMargins.top = .topSpacing
    
    passwordTextFieldContainer.padding = .textFieldPadding
    continueButtonContainer.padding = .buttonPadding
    
    addSubview(titleDescriptionView)
    addSubview(passwordTextFieldContainer)
    passwordTextFieldContainer.setViews([passwordTextField])
    
    addSubview(continueButtonContainer)
    continueButtonContainer.setViews([continueButton])
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
    passwordTextFieldContainer.translatesAutoresizingMaskIntoConstraints = false
    continueButtonContainer.translatesAutoresizingMaskIntoConstraints = false
    
    continueButtonContainerBottomSafeAreaConstraint = continueButtonContainer
      .bottomAnchor
      .constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
    continueButtonContainerBottomConstraint?.isActive = true

    continueButtonContainerBottomConstraint = continueButtonContainer
      .bottomAnchor
      .constraint(equalTo: bottomAnchor)
      .withPriority(.defaultHigh)
    continueButtonContainerBottomConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      titleDescriptionView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
      titleDescriptionView.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor),
      titleDescriptionView.rightAnchor.constraint(equalTo: layoutMarginsGuide.rightAnchor),
      
      passwordTextFieldContainer.topAnchor.constraint(equalTo: titleDescriptionView.bottomAnchor),
      passwordTextFieldContainer.leftAnchor.constraint(equalTo: leftAnchor),
      passwordTextFieldContainer.rightAnchor.constraint(equalTo: rightAnchor),
      
      continueButtonContainer.leftAnchor.constraint(equalTo: leftAnchor),
      continueButtonContainer.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}

private extension CGFloat {
  static let titleBottomPadding: CGFloat = 16
  static let buttonsContainerSpacing: CGFloat = 16
  static let topSpacing: CGFloat = 44
}

private extension UIEdgeInsets {
  static var textFieldPadding = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32)
  static var buttonPadding = UIEdgeInsets(top: 16, left: 32, bottom: 32, right: 32)
}
