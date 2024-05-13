import UIKit
import TKUIKit
import SnapKit

final class WarningBannerView: UIView, ConfigurableView {
  
  let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Accent.orange
    view.alpha = 0.24
    return view
  }()
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.spacing = 16
    stackView.alignment = .center
    return stackView
  }()
  
  let label = UILabel()
  let imageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let text: String
    let image: UIImage
  }
  
  func configure(model: Model) {
    label.attributedText = model.text.withTextStyle(
      .body3,
      color: .Accent.orange,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    imageView.image = model.image
  }
}

private extension WarningBannerView {
  func setup() {
    backgroundView.layer.cornerRadius = 16
    backgroundView.layer.cornerCurve = .continuous
    backgroundView.layer.masksToBounds = true
    
    label.numberOfLines = 0
    
    imageView.tintColor = .Accent.orange
    imageView.contentMode = .center
    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    
    addSubview(backgroundView)
    addSubview(stackView)
    stackView.addArrangedSubview(label)
    stackView.addArrangedSubview(imageView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    backgroundView.snp.makeConstraints { make in
      make.top.equalTo(self).offset(16)
      make.left.bottom.right.equalTo(self)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(backgroundView).inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
    }
  }
}
