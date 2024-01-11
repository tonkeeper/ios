import UIKit

final class SettingsBackupDateView: UIView, ConfigurableView {
  let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    imageView.backgroundColor = .Accent.green
    imageView.tintColor = .Icon.primary
    imageView.image = .Icons.Transaction.walletInitialized
    return imageView
  }()
  
  let stackView = UIStackView()
  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 76)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    imageView.layer.cornerRadius = imageView.bounds.height/2
  }
  
  struct Model {
    let title: String
    let subtitle: String
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.attributed(
      with: .label1,
      alignment: .left,
      color: .Text.primary
    )
    subtitleLabel.attributedText = model.subtitle.attributed(
      with: .body2,
      alignment: .left,
      color: .Text.secondary
    )
  }
}

private extension SettingsBackupDateView {
  func setup() {
    stackView.axis = .vertical
    backgroundColor = .Background.content
    layer.cornerRadius = 16
    
    addSubview(imageView)
    addSubview(stackView)
    
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(subtitleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    imageView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      imageView.widthAnchor.constraint(equalToConstant: 44),
      imageView.heightAnchor.constraint(equalToConstant: 44),
      imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
      imageView.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
      
      stackView.leftAnchor.constraint(equalTo: imageView.rightAnchor, constant: 16),
      stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -16),
      stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
}
