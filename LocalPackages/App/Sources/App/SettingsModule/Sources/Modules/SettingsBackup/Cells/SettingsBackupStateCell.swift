import UIKit
import TKUIKit

final class SettingsBackupStateCell: UICollectionViewCell {
  
  let highlightView = TKHighlightView()
  
  let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    imageView.backgroundColor = .Accent.green
    imageView.tintColor = .Icon.primary
    imageView.image = .App.Icons.Size28.donemark
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
  
  struct Model: Hashable {
    let title: String
    let subtitle: String
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    subtitleLabel.attributedText = model.subtitle.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
  }
}

private extension SettingsBackupStateCell {
  func setup() {
    stackView.axis = .vertical
    backgroundColor = .Background.content
    layer.cornerRadius = 16
    layer.masksToBounds = true
    
    stackView.isUserInteractionEnabled = false
    imageView.isUserInteractionEnabled = false
    
    addSubview(highlightView)
    addSubview(imageView)
    addSubview(stackView)
    
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(subtitleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    imageView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    highlightView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      highlightView.topAnchor.constraint(equalTo: topAnchor),
      highlightView.leftAnchor.constraint(equalTo: leftAnchor),
      highlightView.bottomAnchor.constraint(equalTo: bottomAnchor),
      highlightView.rightAnchor.constraint(equalTo: rightAnchor),
      
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
