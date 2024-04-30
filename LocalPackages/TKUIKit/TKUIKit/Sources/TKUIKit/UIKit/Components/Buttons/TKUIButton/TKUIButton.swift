import UIKit

open class TKUIButton<ButtonContentView: UIView & ConfigurableView, ButtonBackgroundView: UIView>: UIControl, ConfigurableView, TKUIAsyncButtonContentView {
  public let buttonContentView: ButtonContentView
  public let backgroundView: ButtonBackgroundView
  public let contentHorizontalPadding: CGFloat
  
  public var tapAreaInsets: UIEdgeInsets = .zero
  
  public var padding: UIEdgeInsets = .zero {
    didSet {
      setupPadding()
    }
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
  
  public var buttonState: TKButtonState = .normal {
    didSet {
      setupButtonState()
    }
  }
  
  private lazy var backgroundViewTopConstraint: NSLayoutConstraint = {
    backgroundView.topAnchor.constraint(equalTo: topAnchor, constant: padding.top)
  }()
  private lazy var backgroundViewLeftConstraint: NSLayoutConstraint = {
    backgroundView.leftAnchor.constraint(equalTo: leftAnchor, constant: padding.left)
  }()
  private lazy var backgroundViewBottomConstraint: NSLayoutConstraint = {
    backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding.bottom)
  }()
  private lazy var backgroundViewRightConstraint: NSLayoutConstraint = {
    backgroundView.rightAnchor.constraint(equalTo: rightAnchor, constant: -padding.right)
  }()
  
  public init(contentView: ButtonContentView,
              backgroundView: ButtonBackgroundView,
              contentHorizontalPadding: CGFloat = .zero) {
    self.buttonContentView = contentView
    self.backgroundView = backgroundView
    self.contentHorizontalPadding = contentHorizontalPadding
    super.init(frame: .zero)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
    
  public func configure(model: ButtonContentView.Model) {
    buttonContentView.configure(model: model)
  }
  
  open func setupButtonState() {}

  public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds.inset(by: tapAreaInsets)
      .contains(point)
  }
  
  public func addTapAction(_ action: @escaping () -> Void) {
    removeTarget(nil, action: nil, for: .touchUpInside)
    addAction(UIAction(handler: { _ in
      action()
    }), for: .touchUpInside)
  }
  
  // MARK: - TKUIAsyncButtonContentView
  
  public var loaderSize: TKLoaderView.Size {
    .medium
  }
  
  public var contentView: UIView {
    buttonContentView
  }
}

private extension TKUIButton {
  func setup() {
    setContentHuggingPriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.required, for: .horizontal)
    
    backgroundView.isUserInteractionEnabled = false
    buttonContentView.isUserInteractionEnabled = false
    
    addSubview(backgroundView)
    addSubview(buttonContentView)
    
    setupConstraints()
    setupButtonState()
  }
  
  func setupConstraints() {
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    buttonContentView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      backgroundViewTopConstraint,
      backgroundViewLeftConstraint,
      backgroundViewBottomConstraint,
      backgroundViewRightConstraint,
      
      buttonContentView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
      buttonContentView.leftAnchor.constraint(equalTo: backgroundView.leftAnchor, constant: contentHorizontalPadding),
      buttonContentView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
      buttonContentView.rightAnchor.constraint(equalTo: backgroundView.rightAnchor, constant: -contentHorizontalPadding)
    ])
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
  
  func setupPadding() {
    backgroundViewTopConstraint.constant = padding.top
    backgroundViewLeftConstraint.constant = padding.left
    backgroundViewBottomConstraint.constant = -padding.bottom
    backgroundViewRightConstraint.constant = -padding.right
  }
}
