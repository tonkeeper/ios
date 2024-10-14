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
      public let image: UIImage
      public let tintColor: UIColor?
      public let padding: UIEdgeInsets
      public init(image: UIImage, tintColor: UIColor?, padding: UIEdgeInsets) {
        self.image = image
        self.tintColor = tintColor
        self.padding = padding
      }
    }
    public let title: NSAttributedString?
    public let icon: Icon?
    public let action: (() -> Void)?
    
    public init(title: NSAttributedString?,
                icon: Icon?,
                action: (() -> Void)?) {
      self.title = title
      self.icon = icon
      self.action = action
    }
  }
  
  public func configure(model: Model) {
    label.attributedText = model.title
    if let icon = model.icon {
      iconImageView.image = icon.image
      iconImageView.tintColor = icon.tintColor
      iconContainer.isHidden = false
      iconImageView.snp.makeConstraints { make in
        make.edges.equalTo(iconContainer).inset(icon.padding)
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
    stackView.addArrangedSubview(iconContainer)
    
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
