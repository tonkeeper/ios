//
//  Button.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

extension UIControl.State: Hashable {}

final class Button: UIControlClosure {
  
  enum `Type` {
    case primary
    case secondary
    case tertiary
    
    var backgroundColors: [UIControl.State: UIColor] {
      switch self {
      case .primary:
        return [.normal: .Button.primaryBackground,
                .highlighted: .Button.primaryBackgroundHighlighted,
                .disabled: .Button.primaryBackgroundDisabled]
      case .secondary:
        return [.normal: .Button.secondaryBackground,
                .highlighted: .Button.secondaryBackgroundHighlighted,
                .disabled: .Button.secondaryBackgroundDisabled]
      case .tertiary:
        return [.normal: .Button.tertiaryBackground,
                .highlighted: .Button.tertiaryBackgroundHighlighted,
                .disabled: .Button.tertiaryBackgroundDisabled]
      }
    }
    
    var tintColors: [UIControl.State: UIColor] {
      let colors: [UIControl.State: UIColor] = [
        .normal: .Button.primaryForeground,
        .highlighted: .Button.primaryForeground,
        .disabled: .Button.primaryForeground.withAlphaComponent(0.48)
      ]
      return colors
    }
  }
  
  enum Size {
    case xsmall
    case small
    case welter
    case medium
    case large
    case custom(height: CGFloat, cornerRadius: CGFloat, textStyle: TextStyle)
    
    var height: CGFloat {
      switch self {
      case .xsmall: return 32
      case .small: return 36
      case .welter: return 44
      case .medium: return 48
      case .large: return 56
      case let .custom(height, _, _): return height
      }
    }
    
    var cornerRadius: CGFloat {
      switch self {
      case .xsmall: return 0
      case .small: return 18
      case .large: return 16
      case .medium: return 24
      case .welter: return 0
      case let .custom(_, cornerRadius, _): return cornerRadius
      }
    }
    
    var textStyle: TextStyle {
      switch self {
      case .xsmall: return .label2
      case .small: return .label2
      case .large: return .label1
      case .medium: return .label1
      case .welter: return .label1
      case let .custom(_, _, textStyle): return textStyle
      }
    }
  }
  
  enum Shape {
    case circle
    case rect
  }
  
  enum IconPosition {
    case left
    case right
  }
  
  struct Configuration {
    let type: `Type`
    let size: Size
    let shape: Shape
    let contentInsets: UIEdgeInsets
  }
  
  var iconPosition: IconPosition = .left {
    didSet {
      guard iconPosition != oldValue else { return }
      updateIconPosition()
    }
  }
 
  var configuration: Configuration {
    didSet {
      updateConfiguration()
      invalidateIntrinsicContentSize()
    }
  }
  
  let titleLabel = UILabel()
  let iconImageView = UIImageView()
  
  private let contentStackView = UIStackView()
  private let maskLayer = CAShapeLayer()
  private var contentLeftConstraint: NSLayoutConstraint?
  private var contentRightConstraint: NSLayoutConstraint?
  private var contentTopConstraint: NSLayoutConstraint?
  private var contentBottomConstraint: NSLayoutConstraint?
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      updateBackground()
      updateTintColor()
    }
  }
  
  override var isEnabled: Bool {
    didSet {
      guard isEnabled != oldValue else { return }
      updateBackground()
      updateTintColor()
    }
  }
  
  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    maskLayer.frame = bounds
    let path: UIBezierPath
    switch configuration.shape {
    case .circle:
      path = .init(ovalIn: bounds)
    case .rect:
      path = .init(roundedRect: bounds, cornerRadius: configuration.size.cornerRadius)
    }
    maskLayer.path = path.cgPath
    layer.mask = maskLayer
  }
  
  override var intrinsicContentSize: CGSize {
    let height = configuration.size.height
    let width: CGFloat
    switch configuration.shape {
    case .rect:
      width = round(contentStackView.systemLayoutSizeFitting(.zero).width)
    case .circle:
      width = height
    }
    
    let contentSize = CGSize(
      width: width + configuration.contentInsets.left + configuration.contentInsets.right,
      height: height
    )
    return contentSize
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    intrinsicContentSize
  }
  
  override func didMoveToWindow() {
    super.didMoveToWindow()
    maskLayer.rasterizationScale = 2 * (window?.windowScene?.screen.scale ?? 1)
  }
}

private extension Button {
  func setup() {
    maskLayer.shouldRasterize = true
    
    contentStackView.axis = .horizontal
    contentStackView.alignment = .center
    contentStackView.isUserInteractionEnabled = false
    
    contentStackView.addArrangedSubview(iconImageView)
    contentStackView.addArrangedSubview(titleLabel)
    addSubview(contentStackView)
    
    setupConstraints()
    
    updateConfiguration()
    updateBackground()
    updateIconPosition()
  }
  
  func setupConstraints() {
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    
    let contentInsets = configuration.contentInsets
    let topConstraint = contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top)
    let bottomConstraint = contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom)
      .withPriority(.defaultHigh)
    
    self.contentTopConstraint = topConstraint
    self.contentBottomConstraint = bottomConstraint

    NSLayoutConstraint.activate([
      contentStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
      topConstraint,
      bottomConstraint
    ])
  }
  
  func updateBackground() {
    backgroundColor = configuration.type.backgroundColors[state]
  }
  
  func updateTintColor() {
    titleLabel.textColor = configuration.type.tintColors[state]
    iconImageView.tintColor = configuration.type.tintColors[state]
  }
  
  func updateIconPosition() {
    switch iconPosition {
    case .left:
      contentStackView.insertArrangedSubview(iconImageView, at: 0)
    case .right:
      contentStackView.insertArrangedSubview(iconImageView, at: 1)
    }
  }
  
  func updateConfiguration() {
    updateBackground()
    updateTintColor()
    updateContentInsets()
    titleLabel.applyTextStyleFont(configuration.size.textStyle)
  }
  
  func updateContentInsets() {
    let contentInsets = configuration.contentInsets
    contentTopConstraint?.constant = contentInsets.top
    contentBottomConstraint?.constant = -contentInsets.bottom
  }
}
