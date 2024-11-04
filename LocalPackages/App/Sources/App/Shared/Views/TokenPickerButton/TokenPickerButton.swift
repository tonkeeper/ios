import UIKit
import TKUIKit
import SnapKit

final class TokenPickerButton: UIControl {
  
  var didTap: (() -> Void)?
  
  struct Configuration {
    let name: String
    let image: TKImage
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  var padding: UIEdgeInsets = .zero {
    didSet {
      backgroundView.snp.remakeConstraints { make in
        make.edges.equalTo(self).inset(padding)
      }
    }
  }
  
  var contentPadding: UIEdgeInsets = .zero {
    didSet {
      stackView.snp.remakeConstraints { make in
        make.edges.equalTo(backgroundView).inset(contentPadding)
      }
    }
  }
  
  var category: TKActionButtonCategory = .tertiary {
    didSet {
      backgroundView.backgroundColor = category.backgroundColor
    }
  }
  
  override var isHighlighted: Bool {
    didSet {
      backgroundView.backgroundColor = isHighlighted ? category.highlightedBackgroundColor : category.backgroundColor
    }
  }
  
  let imageView = TKImageView()
  let label = UILabel()
  let switchImageView = UIImageView()
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.alignment = .center
    stackView.spacing = 6
    return stackView
  }()
  
  let backgroundView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    backgroundView.layer.cornerRadius = backgroundView.bounds.height/2
  }
  
  private func setup() {
    backgroundView.backgroundColor = category.backgroundColor
    
    addSubview(backgroundView)
    backgroundView.addSubview(stackView)
    
    setContentCompressionResistancePriority(.required, for: .horizontal)
    stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
    switchImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    layer.masksToBounds = true
    
    imageView.contentMode = .scaleAspectFit
    
    backgroundView.isUserInteractionEnabled = false
    
    label.textColor = .Button.tertiaryForeground
    label.font = TKTextStyle.label2.font
    label.isUserInteractionEnabled = false
    
    switchImageView.image = .TKUIKit.Icons.Size16.switch
    switchImageView.tintColor = .Icon.secondary
    switchImageView.isUserInteractionEnabled = false
    
    stackView.isUserInteractionEnabled = false
    
    stackView.addArrangedSubview(imageView)
    stackView.addArrangedSubview(label)
    stackView.addArrangedSubview(switchImageView)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.didTap?()
    }), for: .touchUpInside)
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(padding)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(backgroundView).inset(contentPadding)
    }
    
    imageView.snp.makeConstraints { make in
      make.width.height.equalTo(24)
    }
  }
  
  private func didUpdateConfiguration() {
    guard let configuration else {
      imageView.image = nil
      label.text = nil
      return
    }
    
    imageView.configure(
      model: TKImageView.Model(
        image: configuration.image,
        tintColor: .clear,
        size: .size(CGSize(width: 24, height: 24)),
        corners: .circle,
        padding: .zero
      )
    )
    label.text = configuration.name
  }
}
