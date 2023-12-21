//
//  EnterMnemonicEnterMnemonicView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import UIKit

final class EnterMnemonicView: UIView, ConfigurableView {
  
  let scrollContainer = ScrollContainerWithTitleAndDescription()
  let continueButton = TKButton(configuration: .primaryLarge)
  private lazy var buttonContainer = ButtonBottomContainer(button: continueButton)
  
  var textFields = [MnemonicTextField]()
  
  private var keyboardHeight: CGFloat = 0

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let scrollContainerModel: ScrollContainerWithTitleAndDescription.Model
    let continueButtonTitle: String
  }
  
  func configure(model: Model) {
    scrollContainer.configure(model: model.scrollContainerModel)
    continueButton.configure(model: TKButton.Model(title: .string(model.continueButtonTitle)))
  }
  
  // MARK: - Keyboard
  
  func updateKeyboardHeight(_ height: CGFloat,
                            duration: TimeInterval,
                            curve: UIView.AnimationCurve) {
    keyboardHeight = height
    scrollContainer.scrollContentInset.bottom = height
    layoutIfNeeded()
    UIViewPropertyAnimator(duration: duration, curve: curve) {
      self.layoutIfNeeded()
    }
    .startAnimation()
  }
}

// MARK: - Private

private extension EnterMnemonicView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(scrollContainer)
    scrollContainer.addFooterSubview(SpacingView(verticalSpacing: .constant(.continueButtonTopSpace)))
    scrollContainer.addFooterSubview(buttonContainer)

    (1...Int.wordsCount).forEach { i in
      let textField = MnemonicTextField()
      textField.placeholder = "\(i):"
      scrollContainer.addContentSubview(textField, spacingAfter: .interTextFieldSpace)
      textFields.append(textField)
    }
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollContainer.translatesAutoresizingMaskIntoConstraints = false
    buttonContainer.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollContainer.topAnchor.constraint(equalTo: topAnchor),
      scrollContainer.leftAnchor.constraint(equalTo: leftAnchor),
      scrollContainer.rightAnchor.constraint(equalTo: rightAnchor),
      scrollContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
}

private extension Int {
  static let wordsCount = 24
}

private extension CGFloat {
  static let interTextFieldSpace: CGFloat = 16
  static let continueButtonTopSpace: CGFloat = 16
}
