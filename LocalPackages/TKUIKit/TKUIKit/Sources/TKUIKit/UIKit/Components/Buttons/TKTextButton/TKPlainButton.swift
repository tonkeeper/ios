import UIKit

open class TKPlainButton: UIControl, ConfigurableView {
  
  open override var isHighlighted: Bool {
    didSet {
      stackView.alpha = isHighlighted ? 0.64 : 1
    }
  }
  
  public var padding: UIEdgeInsets = .zero {
    didSet {
      stackView.snp.remakeConstraints { make in
        make.edges.equalTo(self).inset(padding)
      }
    }
  }
  
  public struct Model {
    public struct Icon {
      public enum IconPosition {
        case left
        case right
      }
      public let image: UIImage
      public let tintColor: UIColor?
      public let padding: UIEdgeInsets
      public let iconPosition: IconPosition
      public init(image: UIImage, tintColor: UIColor?, padding: UIEdgeInsets, iconPosition: IconPosition = .right) {
        self.image = image
        self.tintColor = tintColor
        self.padding = padding
        self.iconPosition = iconPosition
      }
    }
    public let title: NSAttributedString?
    public let numberOfLines: Int
    public let icon: Icon?
    public let isEnable: Bool
    public let action: (() -> Void)?
    
    public init(title: NSAttributedString?,
                numberOfLines: Int = 1,
                icon: Icon? = nil,
                isEnable: Bool = true,
                action: (() -> Void)?) {
      self.title = title
      self.numberOfLines = numberOfLines
      self.icon = icon
      self.isEnable = isEnable
      self.action = action
    }
  }
  
  public func configure(model: Model) {
    label.attributedText = model.title
    label.numberOfLines = model.numberOfLines
    if let icon = model.icon {
      iconImageView.image = icon.image
      iconImageView.tintColor = icon.tintColor
      iconContainer.isHidden = false
      iconImageView.snp.makeConstraints { make in
        make.edges.equalTo(iconContainer).inset(icon.padding)
      }
      
      iconContainer.removeFromSuperview()
      switch icon.iconPosition {
      case .left:
        stackView.insertArrangedSubview(iconContainer, at: 0)
      case .right:
        stackView.insertArrangedSubview(iconContainer, at: 1)
      }
      
    } else {
      iconContainer.isHidden = true
    }
    action = model.action
    isUserInteractionEnabled = model.action != nil
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  private let label = UILabel()
  private let iconContainer = UIView()
  private let iconImageView = UIImageView()
  
  private var action: (() -> Void)?
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open override func setContentHuggingPriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) {
    super.setContentHuggingPriority(priority, for: axis)
    stackView.setContentHuggingPriority(priority, for: axis)
    label.setContentHuggingPriority(priority, for: axis)
  }
  
  private func setup() {
    stackView.isUserInteractionEnabled = false
    addSubview(stackView)
    iconContainer.addSubview(iconImageView)
    stackView.addArrangedSubview(label)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.action?()
    }), for: .touchUpInside)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(padding)
    }
  }
}
