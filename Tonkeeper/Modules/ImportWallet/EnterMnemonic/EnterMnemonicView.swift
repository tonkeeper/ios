//
//  EnterMnemonicEnterMnemonicView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 28/06/2023.
//

import UIKit

final class EnterMnemonicView: UIView, ConfigurableView {
  
  let scrollView: UIScrollView = {
    let scrollView = NotDelayScrollView()
    scrollView.showsVerticalScrollIndicator = false
    return scrollView
  }()
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 2
    return label
  }()
  let descriptionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 2
    return label
  }()
  let gradientLayer: CAGradientLayer = {
    let layer = CAGradientLayer()
    layer.colors = [UIColor.Background.page.cgColor, UIColor.clear.cgColor]
    return layer
  }()
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
    let title: NSAttributedString
    let description: NSAttributedString
    let continueButtonTitle: String
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    descriptionLabel.attributedText = model.description
    continueButton.title = model.continueButtonTitle
  }
  
  // MARK: - Layout
  
  override func safeAreaInsetsDidChange() {
    gradientLayer.frame = .init(x: 0, y: 0, width: bounds.width, height: safeAreaInsets.top)
  }
  
  // MARK: - Keyboard
  
  func updateKeyboardHeight(_ height: CGFloat,
                            duration: TimeInterval,
                            curve: UIView.AnimationCurve) {
    keyboardHeight = height
    scrollView.contentInset.bottom = height
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

    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    scrollView.addSubview(buttonContainer)

    contentStackView.addArrangedSubview(titleLabel)
    contentStackView.addArrangedSubview(descriptionLabel)
    contentStackView.setCustomSpacing(.titleBottomSpace, after: titleLabel)
    contentStackView.setCustomSpacing(.descriptionBottomSpace, after: descriptionLabel)
    
    (1...Int.wordsNumber).forEach { i in
      let textField = MnemonicTextField()
      textField.placeholder = "\(i):"
      contentStackView.addArrangedSubview(textField)
      contentStackView.setCustomSpacing(.interTextFieldSpace, after: textField)
      textFields.append(textField)
    }
    
    layer.addSublayer(gradientLayer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    buttonContainer.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrollView.widthAnchor.constraint(equalTo: widthAnchor),

      contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor, constant: .contentSideSpace),
      contentStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor, constant: -.contentSideSpace),

      buttonContainer.topAnchor.constraint(equalTo: contentStackView.bottomAnchor, constant: .continueButtonTopSpace),
      buttonContainer.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      buttonContainer.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      buttonContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      buttonContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
    ])
  }
}

private extension Int {
  static let wordsNumber = 24
}

private extension CGFloat {
  static let contentSideSpace: CGFloat = 32
  static let interTextFieldSpace: CGFloat = 16
  static let titleBottomSpace: CGFloat = 4
  static let descriptionBottomSpace: CGFloat = 32
  static let continueButtonTopSpace: CGFloat = 16
}
