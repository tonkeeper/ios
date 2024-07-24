import UIKit
import TKUIKit

final class StoriesTitleWithSubtitleView: UIView, ConfigurableView {
  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  let contentView = UIView()
  
  public struct Model {
    public let title: String
    public let subtitle: String
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  
  func configure(model: Model) {
    setNeedsLayout()
    setup(title: model.title, subtitle: model.subtitle)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension StoriesTitleWithSubtitleView {
  func setup(title: String, subtitle: String) {
    titleLabel.attributedText = title.withTextStyle(
      .h1,
      color: .Constant.white,
      alignment: .left
    )
    subtitleLabel.attributedText = subtitle.withTextStyle(
      .body1,
      color: .Constant.white,
      alignment: .left
    )
    
    titleLabel.numberOfLines = 0
    subtitleLabel.numberOfLines = 0
    
    contentView.addSubview(titleLabel)
    contentView.addSubview(subtitleLabel)
        
    addSubview(contentView)

    setupConstraints()
  }
  
  func setupConstraints() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: .bottomSpacing),
      contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: .horizontalInset),
      contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -.horizontalInset),
      
      titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
      titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).withPriority(.defaultHigh),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: .subtitleTopInset),
      subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).withPriority(.defaultHigh)
    ])
  }
}

private extension CGFloat {
  static let subtitleTopInset: CGFloat = 8
  static let horizontalInset: CGFloat = 32
  static let bottomSpacing: CGFloat = -28
}
