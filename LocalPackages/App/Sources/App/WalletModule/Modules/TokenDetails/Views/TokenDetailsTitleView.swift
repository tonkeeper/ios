import UIKit
import TKUIKit

final class TokenDetailsTitleView: UIView, ConfigurableView {
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: NSAttributedString?
    let subtitle: NSAttributedString?
    
    init(title: String,
         warning: String?) {
      self.title = title.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
      self.subtitle = warning?.withTextStyle(
        .body2,
        color: .Accent.orange,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
    }
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    subtitleLabel.attributedText = model.subtitle
  }
}

private extension TokenDetailsTitleView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(subtitleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}
