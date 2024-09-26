import UIKit

public final class TKIconButton: UIControl {
  
  public override var isHighlighted: Bool {
    didSet {
      stackView.alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  public override var isEnabled: Bool {
    didSet {
      stackView.alpha = isEnabled ? 1 : 0.32
    }
  }
  
  public struct Configuration {
    public let title: String?
    public let icon: UIImage?
    public let isEnable: Bool
    public let action: (() -> Void)?
    
    public init(title: String?,
                icon: UIImage?,
                isEnable: Bool = true,
                action: (() -> Void)?) {
      self.title = title
      self.icon = icon
      self.isEnable = isEnable
      self.action = action
    }
  }
  
  public var configuration = Configuration(
    title: nil,
    icon: nil,
    action: nil
  ) {
    didSet {
      didUpdateConfiguration()
      invalidateIntrinsicContentSize()
    }
  }
  
  private let iconImageView = UIImageView()
  private let titleLabel = UILabel()
  private let stackView = UIStackView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    stackView.axis = .vertical
    stackView.spacing = 4
    stackView.isUserInteractionEnabled = false
    
    iconImageView.contentMode = .center
    iconImageView.tintColor = .Icon.primary
    
    addSubview(stackView)
    stackView.addArrangedSubview(iconImageView)
    stackView.addArrangedSubview(titleLabel)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.configuration.action?()
    }), for: .touchUpInside)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.left.bottom.right.equalTo(self).inset(
        UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
      )
    }
  }
  
  private func didUpdateConfiguration() {
    titleLabel.attributedText = configuration.title?.withTextStyle(
      .label3,
      color: .Text.secondary,
      alignment: .center
    )
    iconImageView.image = configuration.icon
    
    isEnabled = configuration.isEnable
  }
}
