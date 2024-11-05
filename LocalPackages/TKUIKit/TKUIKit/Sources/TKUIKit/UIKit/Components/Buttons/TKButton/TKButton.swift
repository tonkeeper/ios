import UIKit

open class TKButton: UIControl {

  public var configuration = TKButton.Configuration() {
    didSet {
      didUpdateConfiguration()
    }
  }
  
  public var padding: UIEdgeInsets = .zero {
    didSet { invalidateIntrinsicContentSize() }
  }
  
  open override var isHighlighted: Bool {
    didSet { didUpdateControlState() }
  }
  
  open override var isSelected: Bool {
    didSet { didUpdateControlState() }
  }
  
  open override var isEnabled: Bool {
    didSet { didUpdateControlState() }
  }

  let buttonContentView = TKButtonContentView()
  let loaderView = TKLoaderView(size: .small, style: .primary)
  
  var buttonState: TKButtonState = .normal {
    didSet { didUpdateButtonState() }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public init(configuration: Configuration) {
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open override var intrinsicContentSize: CGSize {
    let contentViewIntrinsicContentSize = buttonContentView.intrinsicContentSize
    let width = contentViewIntrinsicContentSize.width + padding.left + padding.right
    let height = contentViewIntrinsicContentSize.height + padding.top + padding.bottom
    return CGSize(width: width, height: height)
  }
  
  open override func sizeThatFits(_ size: CGSize) -> CGSize {
    let contentViewSizeThatFits = buttonContentView.sizeThatFits(size)
    let width = contentViewSizeThatFits.width + padding.left + padding.right
    let height = contentViewSizeThatFits.height + padding.top + padding.bottom
    return CGSize(width: width, height: height)
  }
  
  open override func layoutSubviews() {
    super.layoutSubviews()
    
    let contentViewSizeThatFits = buttonContentView.sizeThatFits(bounds.size)
    let availableWidth = bounds.width - padding.left - padding.right
    let availableHeight = bounds.height - padding.top - padding.bottom
    
    let contentViewWidth = availableWidth
    let contentViewHeight = min(contentViewSizeThatFits.height, availableHeight)
    
    let contentViewFrame = CGRect(
      x: bounds.width/2 - contentViewWidth/2,
      y: bounds.height/2 - contentViewHeight/2,
      width: contentViewWidth,
      height: contentViewHeight
    )
    buttonContentView.frame = contentViewFrame
    
    loaderView.sizeToFit()
    loaderView.center = CGPoint(
      x: bounds.width/2,
      y: bounds.height/2
    )
  }
  
  open override func setContentHuggingPriority(_ priority: UILayoutPriority,
                                               for axis: NSLayoutConstraint.Axis) {
    super.setContentHuggingPriority(priority, for: axis)
    buttonContentView.setContentHuggingPriority(priority, for: axis)
  }
  
  open override func setContentCompressionResistancePriority(_ priority: UILayoutPriority,
                                                             for axis: NSLayoutConstraint.Axis) {
    super.setContentCompressionResistancePriority(priority, for: axis)
    buttonContentView.setContentCompressionResistancePriority(priority, for: axis)
  }
}

private extension TKButton {
  func setup() {
    buttonContentView.isUserInteractionEnabled = false
    
    loaderView.isHidden = true
    
    addSubview(buttonContentView)
    addSubview(loaderView)
    
    didUpdateConfiguration()
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.configuration.action?()
    }), for: .touchUpInside)
  }
  
  func didUpdateButtonState() {
    buttonContentView.backgroundColor = configuration.backgroundColors[buttonState]
    buttonContentView.titleLabel.alpha = configuration.contentAlpha[buttonState] ?? 1
    buttonContentView.imageView.alpha = configuration.contentAlpha[buttonState] ?? 1
  }
  
  func didUpdateControlState() {
    switch (isEnabled, isHighlighted, isSelected) {
    case (false, _, _):
      buttonState = .disabled
    case (true, true, _):
      buttonState = .highlighted
    case (true, false, true):
      buttonState = .selected
    case (true, false, false):
      buttonState = .normal
    }
  }
  
  func didUpdateConfiguration() {
    self.padding = configuration.padding
    self.buttonContentView.padding = configuration.contentPadding
    self.buttonContentView.spacing = configuration.spacing
    self.buttonContentView.iconPosition = configuration.iconPosition
    self.buttonContentView.iconTintColor = configuration.iconTintColor
    self.buttonContentView.backgroundColor = configuration.backgroundColors[buttonState]
    self.buttonContentView.cornerRadius = configuration.cornerRadius
    self.loaderView.size = configuration.loaderSize
    self.loaderView.style = configuration.loaderStyle
    self.buttonContentView.contentContainerView.isHidden = configuration.showsLoader
    self.loaderView.isHidden = !configuration.showsLoader
    self.isUserInteractionEnabled = !configuration.showsLoader
    self.isEnabled = configuration.isEnabled
    switch configuration.content.title {
    case .plainString(let string):
      self.buttonContentView.title = string.withTextStyle(configuration.textStyle, color: configuration.textColor, alignment: .center)
    case .attributedString(let attributedString):
      self.buttonContentView.title = attributedString
    case .none:
      self.buttonContentView.title = nil
    }
    self.buttonContentView.titleLabel.numberOfLines = configuration.textNumberOfLines
    self.buttonContentView.icon = configuration.content.icon
  }
}
