import UIKit
import TKUIKit

final class WalletContainerWalletButton: UIControl, ConfigurableView {
  
  var didTap: (() -> Void)?
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      backgroundView.alpha = isHighlighted ? 0.88 : 1
    }
  }
  
  struct Model {
    enum Icon {
      case emoji(String)
      case image(UIImage?)
    }
    let title: String
    let icon: Icon
    let color: UIColor
  }
  
  func configure(model: Model) {
    backgroundView.backgroundColor = model.color
    
    titleLabel.attributedText = model.title.withTextStyle(
      .label2,
      color: .white,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    switch model.icon {
    case .emoji(let emoji):
      emojiLabel.isHidden = false
      emojiLabel.text = emoji
      iconImageView.isHidden = true
      iconImageView.image = nil
    case .image(let image):
      emojiLabel.isHidden = true
      emojiLabel.text = nil
      iconImageView.isHidden = false
      iconImageView.image = image
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    return stackView
  }()
  
  private let iconImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .white
    return imageView
  }()
  
  private let titleLabel = UILabel()
  private let emojiLabel = UILabel()
  private let chevronImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    imageView.tintColor = .white
    imageView.image = .TKUIKit.Icons.Size16.chevronDown
    imageView.alpha = 0.64
    return imageView
  }()
  private let backgroundView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    backgroundView.layer.cornerRadius = bounds.height/2
  }
}

private extension WalletContainerWalletButton {
  func setup() {
    backgroundView.layer.cornerCurve = .continuous
    
    stackView.isUserInteractionEnabled = false
    backgroundView.isUserInteractionEnabled = false
    
    stackView.addArrangedSubview(iconImageView)
    stackView.addArrangedSubview(emojiLabel)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(chevronImageView)
    
    stackView.setCustomSpacing(4, after: iconImageView)
    stackView.setCustomSpacing(4, after: emojiLabel)
    stackView.setCustomSpacing(6, after: titleLabel)
    
    addSubview(backgroundView)
    addSubview(stackView)
    
    iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    stackView.snp.makeConstraints { make in
      make.top.left.equalTo(self).offset(10)
      make.bottom.equalTo(self).offset(-10)
      make.right.equalTo(self).offset(-12)
    }
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    iconImageView.snp.makeConstraints { make in
      make.width.height.equalTo(20)
    }
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.didTap?()
    }), for: .touchUpInside)
  }
}
