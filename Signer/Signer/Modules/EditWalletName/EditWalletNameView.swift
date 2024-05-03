import UIKit
import TKUIKit

final class EditWalletNameView: UIView {
  
  let titleDescriptionView: TKTitleDescriptionView = {
    let view = TKTitleDescriptionView(size: .big)
    view.padding = .titleDescriptionPadding
    return view
  }()
  
  let walletNameTextField = TKTextField(
    textFieldInputView: TKTextFieldInputView(
      textInputControl: TKTextInputTextFieldControl()
    )
  )
  let walletNameTextFieldContainer = TKPaddingContainerView()
  
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
    UIViewPropertyAnimator(duration: duration, curve: curve) {
      self.layoutIfNeeded()
    }
    .startAnimation()
  }
  
  func hideKeyboard(duration: TimeInterval,
                    curve: UIView.AnimationCurve) {
    continueButtonContainerBottomConstraint?.isActive = false
    continueButtonContainerBottomConstraint?.constant = 0
    continueButtonContainerBottomSafeAreaConstraint?.isActive = true
    UIViewPropertyAnimator(duration: duration, curve: curve) {
      self.layoutIfNeeded()
    }
    .startAnimation()
  }
}

private extension EditWalletNameView {
  func setup() {
    backgroundColor = .Background.page
    
    directionalLayoutMargins.top = .topSpacing
    
    walletNameTextFieldContainer.padding = .textFieldPadding
    continueButtonContainer.padding = .buttonPadding
    
    addSubview(titleDescriptionView)
    addSubview(walletNameTextFieldContainer)
    walletNameTextFieldContainer.setViews([walletNameTextField])
    
    addSubview(continueButtonContainer)
    continueButtonContainer.setViews([continueButton])
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
    walletNameTextFieldContainer.translatesAutoresizingMaskIntoConstraints = false
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
      
      walletNameTextFieldContainer.topAnchor.constraint(equalTo: titleDescriptionView.bottomAnchor),
      walletNameTextFieldContainer.leftAnchor.constraint(equalTo: leftAnchor),
      walletNameTextFieldContainer.rightAnchor.constraint(equalTo: rightAnchor),
      
      continueButtonContainer.leftAnchor.constraint(equalTo: leftAnchor),
      continueButtonContainer.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}

private extension CGFloat {
  static let buttonsContainerSpacing: CGFloat = 16
  static let topSpacing: CGFloat = 44
}

private extension NSDirectionalEdgeInsets {
  static let titleDescriptionPadding = NSDirectionalEdgeInsets(
    top: 0,
    leading: 32,
    bottom: 16,
    trailing: 32
  )
}

private extension UIEdgeInsets {
  static var textFieldPadding = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32)
  static var buttonPadding = UIEdgeInsets(top: 16, left: 32, bottom: 32, right: 32)
}
