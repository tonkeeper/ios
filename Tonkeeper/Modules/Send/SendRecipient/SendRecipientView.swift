//
//  SendRecipientSendRecipientView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 31/05/2023.
//

import UIKit

final class SendRecipientView: UIView {
  private let scrollView = UIScrollView()
  private let contentView = UIView()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  let addressTextField = TextField()
  let commentTextField = TextField()
  
  let commentVisibilityLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.textAlignment = .left
    label.text = "The comment is visible to everyone."
    label.isHidden = true
    return label
  }()
  
  let commentLimitLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.isHidden = true
    return label
  }()
  
  lazy var continueButtonActivityContainer = ActivityViewContainer(view: continueButton)
  let continueButton: TKButton = {
    let button = TKButton(configuration: .primaryLarge)
    button.titleLabel.text = "Continue"
    return button
  }()
  
  private var keyboardHeight: CGFloat = 0
  private var continueButtonBottomConstraint: NSLayoutConstraint?

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    updateContinueButtonBottomConstraint()
  }
  
  // MARK: - Keyboard
  
  func updateKeyboardHeight(_ height: CGFloat,
                            duration: TimeInterval,
                            curve: UIView.AnimationCurve) {
    keyboardHeight = height
    updateContinueButtonBottomConstraint()
    UIViewPropertyAnimator(duration: duration, curve: curve) {
      self.layoutIfNeeded()
    }
    .startAnimation()
  }
}

// MARK: - Private

private extension SendRecipientView {
  func setup() {
    backgroundColor = .Background.page
    
    addressTextField.isPasteButtonAvailable = true
    addressTextField.isScanQRCodeButtonAvailable = true
    addressTextField.textView.autocapitalizationType = .none
    addressTextField.textView.autocorrectionType = .no
    addressTextField.textView.keyboardType = .alphabet
    
    addSubview(scrollView)
    addSubview(continueButtonActivityContainer)
    scrollView.addSubview(stackView)

    stackView.addArrangedSubview(addressTextField)
    stackView.addArrangedSubview(commentTextField)
    stackView.addArrangedSubview(commentVisibilityLabel)
    stackView.addArrangedSubview(commentLimitLabel)
    
    stackView.setCustomSpacing(.textFieldSpace, after: addressTextField)
    stackView.setCustomSpacing(.commentaryVisibilityLabelTopSpace, after: commentTextField)
    stackView.setCustomSpacing(.commentaryVisibilityLabelTopSpace, after: commentVisibilityLabel)
    
    setupConstraints()
    updateContinueButtonBottomConstraint()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    continueButtonActivityContainer.translatesAutoresizingMaskIntoConstraints = false
    
    continueButtonBottomConstraint = continueButtonActivityContainer.bottomAnchor.constraint(
      equalTo: bottomAnchor)
    continueButtonBottomConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

      stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      stackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      stackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      
      continueButtonActivityContainer.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      continueButtonActivityContainer.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
    ])
  }
  
  func updateContinueButtonBottomConstraint() {
    let inset = keyboardHeight == 0
    ? -safeAreaInsets.bottom - .continueButtonBottomSpace
    : -keyboardHeight - .continueButtonBottomSpace
    continueButtonBottomConstraint?.constant = inset
    scrollView.contentInset.bottom = -(inset - continueButtonActivityContainer.frame.height - .continueButtonBottomSpace)
  }
}

private extension CGFloat {
  static let textFieldSpace: CGFloat = 16
  static let commentaryVisibilityLabelTopSpace: CGFloat = 12
  static let continueButtonBottomSpace: CGFloat = 16
}
