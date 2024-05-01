import UIKit

public protocol TKHeaderButtonContent: UIView, ConfigurableView {
  var padding: NSDirectionalEdgeInsets { get }
  
  func setForegroudColor(_ color: UIColor)
}

public final class TKHeaderButton<ButtonContent: TKHeaderButtonContent>: UIControl, ConfigurableView {
  private var buttonState: TKButtonState = .normal {
    didSet {
      didUpdateState()
    }
  }
  
  private var tapAction: (() -> Void)?
  private let buttonContent: ButtonContent
  private let maskLayer = CAShapeLayer()
  
  init(buttonContent: ButtonContent) {
    self.buttonContent = buttonContent
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    maskLayer.frame = bounds
    maskLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height/2).cgPath
    layer.mask = maskLayer
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

private extension TKHeaderButton {
  func setup() {
    buttonContent.isUserInteractionEnabled = false
    addSubview(buttonContent)
    didUpdateState()
    
    setupConstraints()
  }
  
  func setupConstraints() {
    setContentHuggingPriority(.required, for: .horizontal)
    setContentHuggingPriority(.required, for: .vertical)
    
    buttonContent.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      buttonContent.topAnchor.constraint(
        equalTo: topAnchor, 
        constant: buttonContent.padding.top
      ),
      buttonContent.leadingAnchor.constraint(
        equalTo: leadingAnchor,
        constant: buttonContent.padding.leading
      ),
      buttonContent.bottomAnchor.constraint(
        equalTo: bottomAnchor,
        constant: -buttonContent.padding.bottom
      ).withPriority(.defaultHigh),
      buttonContent.trailingAnchor.constraint(
        equalTo: trailingAnchor,
        constant: -buttonContent.padding.trailing
      ).withPriority(.defaultHigh)
    ])
  }
  
  func didUpdateState() {
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    switch buttonState {
    case .normal:
      backgroundColor = .Button.secondaryBackground
      foregroundColor = .Button.secondaryForeground
    case .highlighted:
      backgroundColor = .Button.secondaryBackgroundHighlighted
      foregroundColor = .Button.secondaryForeground
    case .disabled:
      backgroundColor = .Button.secondaryBackgroundDisabled
      foregroundColor = .Button.secondaryForeground.withAlphaComponent(0.45)
    }
    self.backgroundColor = backgroundColor
    buttonContent.setForegroudColor(foregroundColor)
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
}
