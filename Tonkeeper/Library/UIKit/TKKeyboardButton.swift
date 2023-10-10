//
//  TKKeyboardButton.swift
//  Tonkeeper
//
//  Created by Grigory on 21.7.23..
//

import UIKit

final class TKKeyboardButton: UIControlClosure {
  
  enum Size: CGFloat {
    case small
    case big
    
    var buttonHeight: CGFloat {
      switch self {
      case .big:
        return .buttonBigHeight
      case .small:
        return .buttonSmallHeight
      }
    }
  }

  enum ButtonType {
    enum BiometryButton {
      case faceId
      case touchId
    }
    
    case digit(Int)
    case backspace
    case biometry(BiometryButton)
    case decimalSeparator
    
    var title: String? {
      switch self {
      case let .digit(digit):
        return "\(digit)"
      case .backspace:
        return nil
      case .biometry:
        return nil
      case .decimalSeparator:
        return Locale.current.decimalSeparator
      }
    }
    
    var image: UIImage? {
      switch self {
      case .digit:
        return nil
      case .backspace:
        return .Icons.PasscodeButton.backspace
      case .biometry(let button):
        switch button {
        case .faceId:
          return .Icons.PasscodeButton.faceId
        case .touchId:
          return .Icons.PasscodeButton.touchId
        }
      case .decimalSeparator:
        return nil
      }
    }
  }
  
  struct Style {
    enum BackgroundShape {
      case round
      case rect
      
      var unhightlightTransform: CGAffineTransform {
        switch self {
        case .rect:
          return .identity
        case .round:
          return .init(scaleX: .notHighlightedScale, y: .notHighlightedScale)
        }
      }
      var highlightTransform: CGAffineTransform {
        switch self {
        case .rect:
          return .identity
        case .round:
          return .identity
        }
      }
    }
    
    enum BackgroundColor {
      case clear
      case tint
      
      var tintViewBackgroundColor: UIColor {
        switch self {
        case .clear: return .clear
        case .tint: return .Button.secondaryBackground
        }
      }
      
      var highlighViewBackgroundColor: UIColor {
        switch self {
        case .clear: return .Button.secondaryBackground
        case .tint: return .Button.secondaryBackgroundHighlighted
        }
      }
    }
    
    let backgroundShape: BackgroundShape
    let backgroundColor: BackgroundColor
  }
  
  // MARK: - Subviews
  
  private let button: UIButton = {
    let button = UIButton(type: .custom)
    button.isUserInteractionEnabled = false
    return button
  }()
  private lazy var tintView: UIView = {
    let view = UIView()
    view.backgroundColor = style.backgroundColor.tintViewBackgroundColor
    view.transform = style.backgroundShape.unhightlightTransform
    view.isUserInteractionEnabled = false
    return view
  }()
  
  // MARK: - State
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      updateIsHighlightedState()
    }
  }
  
  let buttonType: ButtonType
  let style: Style
  var size: Size = .big {
    didSet {
      invalidateIntrinsicContentSize()
    }
  }
  
  // MARK: - Init
  
  init(buttonType: ButtonType,
       style: Style) {
    self.buttonType = buttonType
    self.style = style
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    switch style.backgroundShape {
    case .round:
      tintView.layer.cornerRadius = bounds.height / 2
    case .rect:
      tintView.layer.cornerRadius = .tintCornerRadius
    }
  }
  
  override var intrinsicContentSize: CGSize {
    return .init(width: UIView.noIntrinsicMetric, height: size.buttonHeight)
  }
}

// MARK: - Setup

private extension TKKeyboardButton {
  func setup() {
    addSubview(tintView)
    addSubview(button)
    
    button.titleLabel?.applyTextStyleFont(.num1)
    button.titleLabel?.textColor = .Text.primary
    button.titleLabel?.textAlignment = .center
    button.tintColor = .Icon.primary
    
    button.setTitle(buttonType.title, for: .normal)
    button.setImage(buttonType.image, for: .normal)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    button.translatesAutoresizingMaskIntoConstraints = false
    tintView.translatesAutoresizingMaskIntoConstraints = false
    
    switch style.backgroundShape {
    case .round:
      NSLayoutConstraint.activate([
        tintView.heightAnchor.constraint(equalTo: heightAnchor),
        tintView.widthAnchor.constraint(equalTo: heightAnchor),
        tintView.centerXAnchor.constraint(equalTo: centerXAnchor),
        tintView.centerYAnchor.constraint(equalTo: centerYAnchor)
      ])
    case .rect:
      NSLayoutConstraint.activate([
        tintView.topAnchor.constraint(equalTo: topAnchor),
        tintView.leftAnchor.constraint(equalTo: leftAnchor),
        tintView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh),
        tintView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh)
      ])
    }
    
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: topAnchor),
      button.leftAnchor.constraint(equalTo: leftAnchor),
      button.rightAnchor.constraint(equalTo: rightAnchor),
      button.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
  
  func updateIsHighlightedState() {
    let transform = isHighlighted ? style.backgroundShape.highlightTransform : style.backgroundShape.unhightlightTransform
    let backgroundColor: UIColor = isHighlighted ? style.backgroundColor.highlighViewBackgroundColor : style.backgroundColor.tintViewBackgroundColor

    let animation = {
      self.tintView.backgroundColor = backgroundColor
      self.tintView.transform = transform
    }
    UIView.animate(withDuration: .animationDuration, delay: 0, options: [.curveEaseInOut]) {
      animation()
    }
  }
}

private extension CGFloat {
  static let buttonBigHeight: CGFloat = 72
  static let buttonSmallHeight: CGFloat = 52
  static let notHighlightedScale: CGFloat = 0.8
  static let highlightScale: CGFloat = 1
  static let tintCornerRadius: CGFloat = 16
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.2
}

