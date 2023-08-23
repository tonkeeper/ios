//
//  MoreTextViewContainer.swift
//  Tonkeeper
//
//  Created by Grigory on 22.8.23..
//

import UIKit

final class MoreTextViewContainer: UIView {
  
  private let textView: UITextView = {
    let textView = UITextView()
    textView.isScrollEnabled = false
    textView.font = TextStyle.body2.font
    textView.backgroundColor = .clear
    textView.textColor = .Text.secondary
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.isSelectable = false
    return textView
  }()
  
  private let moreButton = MoreButton()
  
  var isCollapsed = true {
    didSet {
      update()
    }
  }
  var numberOfLinesInCollapsed = 3 {
    didSet {
      update()
    }
  }
  
  var attributedText: NSAttributedString? {
    didSet {
      textView.attributedText = attributedText
      update()
    }
  }
  
  private var textViewHeightConstraint: NSLayoutConstraint?
  private var textViewBottomConstraint: NSLayoutConstraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension MoreTextViewContainer {
  func setup() {
    addSubview(textView)
    addSubview(moreButton)
    
    moreButton.button.addTarget(self, action: #selector(didTapReadMoreButton), for: .touchUpInside)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    textView.translatesAutoresizingMaskIntoConstraints = false
    moreButton.translatesAutoresizingMaskIntoConstraints = false
    
    textViewBottomConstraint = textView.bottomAnchor.constraint(equalTo: bottomAnchor)
    textViewBottomConstraint?.isActive = true
    textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 0)
    textViewHeightConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: topAnchor),
      textView.leftAnchor.constraint(equalTo: leftAnchor),
      textView.rightAnchor.constraint(equalTo: rightAnchor),
      
      moreButton.bottomAnchor.constraint(equalTo: bottomAnchor),
      moreButton.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  @objc
  func didTapReadMoreButton() {
    isCollapsed = false
  }
  
  func update() {
    guard isCollapsed else {
      textViewHeightConstraint?.isActive = false
      moreButton.isHidden = true
      return
    }
    
    moreButton.isHidden = false
    guard let attributedText = attributedText else {
      textViewHeightConstraint?.constant = 0
      return
    }
    
    let lineHeight: CGFloat
    if let paragraphStyle = attributedText.attributes(at: 0, effectiveRange: nil)[.paragraphStyle] as? NSParagraphStyle {
      lineHeight = paragraphStyle.minimumLineHeight
    } else {
      lineHeight = 0
    }
    let maximumHeight = lineHeight * CGFloat(numberOfLinesInCollapsed)
    let textHeight = ceil(attributedText.boundingRect(with: .init(width: bounds.width,
                                                             height: CGFloat.greatestFiniteMagnitude),
                                                 options: [.usesFontLeading, .usesLineFragmentOrigin],
                                                 context: nil).size.height)
    
    textViewHeightConstraint?.constant = min(maximumHeight, textHeight)
  }
}

private final class MoreButton: UIControl {
  let button: UIButton = {
    let button = UIButton(type: .system)
    button.setTitleColor(.Text.accent, for: .normal)
    button.titleLabel?.applyTextStyleFont(.body2)
    button.setTitle("More", for: .normal)
    button.titleEdgeInsets = .zero
    button.contentEdgeInsets = .zero
    return button
  }()
  
  private let gradientLayer: CAGradientLayer = {
    let layer = CAGradientLayer()
    layer.colors = [UIColor.Background.content.withAlphaComponent(0.0).cgColor, UIColor.Background.content.cgColor, UIColor.Background.content.cgColor]
    layer.startPoint = CGPoint(x: 0, y: 0.5)
    layer.endPoint = CGPoint(x: 1, y: 0.5)
    return layer
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()

    gradientLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
    button.sizeToFit()
    button.frame.origin = CGPoint(x: .gradientWidth, y: bounds.height/2 - button.bounds.height/2)
  }
  
  override var intrinsicContentSize: CGSize {
    return sizeThatFits(.zero)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let buttonSize = button.sizeThatFits(.zero)
    return CGSize(width: buttonSize.width + .gradientWidth, height: 20)
  }
  
  private func setup() {
    layer.addSublayer(gradientLayer)
    addSubview(button)
  }
}

private extension CGFloat {
  static let gradientWidth: CGFloat = 42
}
