import UIKit

public final class TKListTitleView: UIView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {
  
  public var didTapButton: (() -> Void)?
  
  private var padding: UIEdgeInsets = .zero
  
  public struct Model: Hashable {
    public let title: String?
    public let textStyle: TKTextStyle
    public let buttonContent: TKButton.Configuration.Content?
    public let padding: UIEdgeInsets
    
    public init(title: String?,
                textStyle: TKTextStyle,
                buttonContent: TKButton.Configuration.Content? = nil,
                padding: UIEdgeInsets = .zero) {
      self.title = title
      self.textStyle = textStyle
      self.buttonContent = buttonContent
      self.padding = padding
    }
  }
  
  public let titleLabel: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.h3.font
    label.textColor = .Text.primary
    label.textAlignment = .left
    return label
  }()
  
  private let button = TKButton(configuration: .titleHeaderButtonConfiguration(category: .secondary))
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    return stackView
  }()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let stackViewSize = systemLayoutSizeFitting(
      size,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultLow
    )
    let height = stackViewSize.height + padding.top + padding.bottom
    return CGSize(width: size.width, height: height)
  }
  
  public func prepareForReuse() {
    titleLabel.text = nil
  }
  
  public override func setContentHuggingPriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) {
    super.setContentHuggingPriority(priority, for: axis)
    
    stackView.setContentHuggingPriority(priority, for: axis)
    titleLabel.setContentHuggingPriority(priority, for: axis)
  }
  
  public func configure(model: Model) {
    titleLabel.text = model.title
    titleLabel.font = model.textStyle.font
    if let buttonContent = model.buttonContent {
      button.configuration.content = buttonContent
      button.isHidden = false
    } else {
      button.isHidden = true
    }
    self.padding = model.padding
    stackView.snp.remakeConstraints { make in
      make.edges.equalTo(model.padding)
    }
  }
}

private extension TKListTitleView {
  func setup() {
    button.configuration.action = { [weak self] in
      self?.didTapButton?()
    }
    
    addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(button)
//    backgroundColor = .Background.page
//    
//    titleLabel.backgroundColor = .Background.page
    
    button.setContentHuggingPriority(.required, for: .horizontal)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(padding)
    }
  }
}
