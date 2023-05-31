//
//  TextField.swift
//  Tonkeeper
//
//  Created by Grigory on 31.5.23..
//

import UIKit

final class TextField: UIControlClosure {
  
  enum PlaceholderMode {
    case topStick
    case noStick
  }
  
  enum ValidationState {
    case valid
    case invalid
  }
  
  var placeholder: String? {
    get { placeholderLabel.text }
    set { placeholderLabel.text = newValue }
  }
  
  var validationState: ValidationState = .valid {
    didSet {
      updateAppearance()
    }
  }
  
  var placeholderMode: PlaceholderMode = .topStick {
    didSet {
      updatePlaceholderModeAppearance()
    }
  }
  
  private let container = TextFieldContainer()
  private let textView: UITextView = {
    let textView = UITextView()
    textView.backgroundColor = .clear
    textView.font = TextStyle.body1.font
    textView.textColor = .Text.primary
    textView.textContainer.lineFragmentPadding = 0
    textView.textContainerInset = .init(
      top: TextStyle.body1.lineSpacing/2,
      left: 0,
      bottom: TextStyle.body1.lineSpacing/2,
      right: 0)
    textView.isScrollEnabled = false
    return textView
  }()
  
  private let placeholderLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body1)
    label.textColor = .Text.secondary
    label.textAlignment = .left
    label.numberOfLines = 1
    return label
  }()
  
  private var textViewTopConstraint: NSLayoutConstraint?
  private var textViewBottomConstraint: NSLayoutConstraint?
  
  private var placeholderCenterYConstraint: NSLayoutConstraint?
  private var placeholderTopConstraint: NSLayoutConstraint?
  private var placeholderLeftConstraint: NSLayoutConstraint?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func becomeFirstResponder() -> Bool {
    let result = textView.becomeFirstResponder()
    updatePlaceholder(isFirstResponder: result)
    return result
  }
  
  override func resignFirstResponder() -> Bool {
    let result = textView.resignFirstResponder()
    updatePlaceholder(isFirstResponder: !result)
    return result
  }
}

private extension TextField {
  func setup() {
    addAction(.init(handler: { [weak self] in
      self?.textView.becomeFirstResponder()
    }), for: .touchUpInside)
    
    container.isUserInteractionEnabled = false
    
    textView.delegate = self
    
    addSubview(container)
    addSubview(textView)
    addSubview(placeholderLabel)
    
    container.translatesAutoresizingMaskIntoConstraints = false
    textView.translatesAutoresizingMaskIntoConstraints = false
    placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
    
    textViewTopConstraint = textView.topAnchor.constraint(equalTo: topAnchor, constant: 0)
    textViewBottomConstraint = textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
    textViewTopConstraint?.isActive = true
    textViewBottomConstraint?.isActive = true
    
    placeholderTopConstraint = placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: .placeholderTopActiveSpace)
    placeholderCenterYConstraint = placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
    placeholderCenterYConstraint?.isActive = true
    placeholderLeftConstraint = placeholderLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: .placeholderLeftInactiveSpace)
    placeholderLeftConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      textView.leftAnchor.constraint(equalTo: leftAnchor, constant: .textViewSideSpace),
      textView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.textViewSideSpace),
      
      container.topAnchor.constraint(equalTo: topAnchor),
      container.leftAnchor.constraint(equalTo: leftAnchor),
      container.rightAnchor.constraint(equalTo: rightAnchor),
      container.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
    
    updatePlaceholderModeAppearance()
    updateAppearance()
  }
  
  func updateAppearance() {
    switch validationState {
    case .valid:
      container.validationState = .valid
      textView.tintColor = .Field.activeBorder
    case .invalid:
      container.validationState = .invalid
      textView.tintColor = .Field.errorBorder
    }
  }
  
  func updatePlaceholderModeAppearance() {
    switch placeholderMode {
    case .noStick:
      textViewTopConstraint?.constant = .textViewTopSpace
      textViewBottomConstraint?.constant = -.textViewBottomSpace
    case .topStick:
      textViewTopConstraint?.constant = .textViewPlaceholderTopSpace
      textViewBottomConstraint?.constant = -.textViewPlaceholderBottomSpace
    }
  }
  
  func updatePlaceholder(isFirstResponder: Bool) {
    switch placeholderMode {
    case .topStick:
      if isFirstResponder {
        movePlaceholderTop()
      } else if textView.text.isEmpty {
        movePlaceholderBottom()
      }
    case .noStick:
      return
    }
  }
  
  func movePlaceholderTop() {
    placeholderCenterYConstraint?.isActive = false
    placeholderTopConstraint?.isActive = true
    placeholderLeftConstraint?.constant = .placeholderLeftActiveSpace
    let transform = CGAffineTransform(scaleX: .placeholderScale, y: .placeholderScale)
    
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.placeholderLabel.transform = transform
      self.layoutIfNeeded()
    }
  }
  
  func movePlaceholderBottom() {
    placeholderCenterYConstraint?.isActive = true
    placeholderTopConstraint?.isActive = false
    placeholderLeftConstraint?.constant = .placeholderLeftInactiveSpace
    let transform = CGAffineTransform.identity
    
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.placeholderLabel.transform = transform
      self.layoutIfNeeded()
    }
  }
}

extension TextField: UITextViewDelegate {
  func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
    updatePlaceholder(isFirstResponder: true)
    container.state = .active
    return true
  }
  
  func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
    updatePlaceholder(isFirstResponder: false)
    container.state = .inactive
    return true
  }
  
  func textViewDidChange(_ textView: UITextView) {
    switch placeholderMode {
    case .noStick:
      placeholderLabel.isHidden = !textView.text.isEmpty
    case .topStick:
      return
    }
  }
}

private extension CGFloat {
  static let textViewSideSpace: CGFloat = 16
  static let textViewPlaceholderTopSpace: CGFloat = 28
  static let textViewPlaceholderBottomSpace: CGFloat = 12
  static let textViewTopSpace: CGFloat = 16
  static let textViewBottomSpace: CGFloat = 16
  static let placeholderScale: CGFloat = 0.75
  
  static let placeholderLeftInactiveSpace: CGFloat = 16
  static let placeholderLeftActiveSpace: CGFloat = 10
  static let placeholderTopActiveSpace: CGFloat = 12
}
