import UIKit

public protocol TKFlatButtonContent: UIView, ConfigurableView {
  var buttonState: TKButtonState { get set }
}

public final class TKFlatButtonControl<ButtonContent: TKFlatButtonContent>: UIControl, ConfigurableView {
  private var buttonState: TKButtonState = .normal {
    didSet {
      didUpdateState()
    }
  }
  
  private var tapAction: (() -> Void)?
  private let buttonContent: ButtonContent
  
  init(buttonContent: ButtonContent) {
    self.buttonContent = buttonContent
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    buttonContent.frame = bounds
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

private extension TKFlatButtonControl {
  func setup() {
    buttonContent.isUserInteractionEnabled = false
    addSubview(buttonContent)
    didUpdateState()
    setupConstraints()
  }
  
  func setupConstraints() {
    buttonContent.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      buttonContent.topAnchor.constraint(equalTo: topAnchor),
      buttonContent.leftAnchor.constraint(equalTo: leftAnchor),
      buttonContent.bottomAnchor.constraint(equalTo: bottomAnchor),
      buttonContent.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func didUpdateState() {
    buttonContent.buttonState = buttonState
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

