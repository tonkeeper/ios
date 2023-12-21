import UIKit
import TKUIKit

protocol TKButtonContent: UIView, ConfigurableView {
  func width(withHeight height: CGFloat) -> CGFloat
  func setForegroundColor(_ color: UIColor)
}

protocol TKButtonTextContent: TKButtonContent {
  func setTextStyle(_ textStyle: TextStyle)
}

public enum TKButtonState {
  case normal
  case highlighted
  case disabled
}

final class TKButtonControl<ButtonContent: TKButtonContent>: UIControl, ConfigurableView {
  
  private let backgroundView: TKButtonBackgroundView
  private var tapAction: (() -> Void)?
  
  var buttonContent: ButtonContent
  let buttonCategory: TKButtonCategory
  let buttonSize: TKButtonSize
  
  private var buttonState: TKButtonState = .normal {
    didSet {
      didUpdateState()
    }
  }
  
  public init(buttonContent: ButtonContent,
              buttonCategory: TKButtonCategory,
              buttonSize: TKButtonSize) {
    self.buttonContent = buttonContent
    self.buttonCategory = buttonCategory
    self.buttonSize = buttonSize
    self.backgroundView = TKButtonBackgroundView(
      buttonCategory: buttonCategory,
      cornerRadius: buttonSize.cornerRadius
    )
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    backgroundView.frame = bounds
    buttonContent.frame = bounds.inset(by: buttonSize.padding)
  }
  
  public override var intrinsicContentSize: CGSize {
    let height = buttonSize.height
    let contentHeight = height - buttonSize.padding.bottom - buttonSize.padding.top
    let contentWidth = buttonContent.width(withHeight: contentHeight)
    let width = contentWidth + buttonSize.padding.left + buttonSize.padding.right
    return CGSize(width: width, height: height)
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    intrinsicContentSize
  }
  
  public override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      didUpdateIsHighlightedOrIsEnabled()
    }
  }
  
  public override var isEnabled: Bool {
    didSet {
      guard isEnabled != oldValue else { return }
      didUpdateIsHighlightedOrIsEnabled()
    }
  }
  
  public func addTapAction(_ tapAction: @escaping () -> Void) {
    if self.tapAction == nil {
      addTarget(self, action: #selector(touchUpInsideAction), for: .touchUpInside)
    }
    self.tapAction = tapAction
  }
  
  @objc
  private func touchUpInsideAction() {
    tapAction?()
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    let contentModel: ButtonContent.Model
    let action: () -> Void
    
    public init(contentModel: ButtonContent.Model, action: @escaping () -> Void) {
      self.contentModel = contentModel
      self.action = action
    }
  }
  
  public func configure(model: Model) {
    buttonContent.configure(model: model.contentModel)
    addTapAction(model.action)
  }
}

private extension TKButtonControl {
  func setup() {
    buttonContent.isUserInteractionEnabled = false
    
    addSubview(backgroundView)
    addSubview(buttonContent)
    
    updateContent()
    updateBackground()
  }
  
  func didUpdateState() {
    UIView.animate(withDuration: 0.1) {
      self.updateContent()
      self.updateBackground()
    }
  }
  
  func updateContent() {
    buttonContent.setForegroundColor(foregroundColor)
    (buttonContent as? any TKButtonTextContent)?.setTextStyle(buttonSize.textStyle)
  }
  
  func updateBackground() {
    backgroundView.state = buttonState
  }
  
  func didUpdateIsHighlightedOrIsEnabled() {
    switch (isHighlighted, isEnabled) {
    case (false, false):
      buttonState = .disabled
    case (true, false):
      buttonState = .disabled
    case (false, true):
      buttonState = .normal
    case (true, true):
      buttonState = .highlighted
    }
  }
  
  var foregroundColor: UIColor {
    switch buttonState {
    case .normal:
      return buttonCategory.titleColor
    case .highlighted:
      return buttonCategory.titleColor
    case .disabled:
      return buttonCategory.disabledTitleColor
    }
  }
}
