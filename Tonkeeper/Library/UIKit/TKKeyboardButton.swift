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
    case digit(Int)
    case backspace
    case biometry
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
      case .biometry:
        return .Icons.PasscodeButton.biometry
      case .decimalSeparator:
        return nil
      }
    }
  }
  
  struct Style {
    enum BackgroundShape {
      case round
      case rect
      
      var unhightlightScale: CGFloat {
        switch self {
        case .rect:
          return .highlightScale
        case .round:
          return .notHighlightedScale
        }
      }
      var highlightScale: CGFloat {
        switch self {
        case .rect:
          return .highlightScale
        case .round:
          return .highlightScale
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
    view.isUserInteractionEnabled = false
    return view
  }()
  
  // MARK: - State
  
  override var isHighlighted: Bool {
    didSet {
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
    button.frame = bounds
    
    switch style.backgroundShape {
    case .round:
      tintView.frame = .init(x: bounds.width/2 - bounds.height/2, y: 0, width: bounds.height, height: bounds.height)
      tintView.layer.cornerRadius = bounds.height / 2
    case .rect:
      tintView.frame = bounds.insetBy(dx: 4, dy: 4)
      tintView.layer.cornerRadius = 16
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
  }
  
  func updateIsHighlightedState() {
    let startScale = isHighlighted ? style.backgroundShape.highlightScale : style.backgroundShape.unhightlightScale
    let finalScale = isHighlighted ? style.backgroundShape.unhightlightScale : style.backgroundShape.highlightScale
    tintView.transform = CGAffineTransform(scaleX: startScale, y: startScale)
    let backgroundColor: UIColor = isHighlighted ? style.backgroundColor.highlighViewBackgroundColor : style.backgroundColor.tintViewBackgroundColor
    let animation = {
      self.tintView.backgroundColor = backgroundColor
      self.tintView.transform = CGAffineTransform(scaleX: finalScale, y: finalScale)
    }
    UIView.animate(withDuration: .animationDuration, delay: 0, options: [.curveEaseInOut]) {
      animation()
    }
  }
}

private extension CGFloat {
  static let buttonBigHeight: CGFloat = 72
  static let buttonSmallHeight: CGFloat = 60
  static let notHighlightedScale: CGFloat = 0.8
  static let highlightScale: CGFloat = 1
}

private extension TimeInterval {
  static let animationDuration: TimeInterval = 0.2
}

