import UIKit
import TKUIKit

final class HistoryEventOpenTransactionButton: UIControl, ConfigurableView {
  
  private let titleLabel = UILabel()
  private let iconImageView = UIImageView()
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 8
    return stackView
  }()
  
  override var isHighlighted: Bool {
    didSet {
      backgroundColor = isHighlighted ? .Button.secondaryBackgroundHighlighted : .Button.secondaryBackground
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 36)
  }
  
  struct Model {
    let title: NSAttributedString?
    let icon: UIImage?
    
    init(title: String, 
         transactionHash: String,
         image: UIImage?) {
      let transaction = title.withTextStyle(
        .label2,
        color: .Button.primaryForeground,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
      let hash = transactionHash.withTextStyle(
        .label2,
        color: .Text.tertiary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
      let result = NSMutableAttributedString(attributedString: transaction)
      result.append(hash)
      self.title = result
      self.icon = image
    }
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    iconImageView.image = model.icon
  }
}

private extension HistoryEventOpenTransactionButton {
  func setup() {
    iconImageView.contentMode = .center
    iconImageView.tintColor = .Icon.primary
    
    contentStackView.isUserInteractionEnabled = false
    
    backgroundColor = .Button.secondaryBackground
    
    layer.cornerRadius = 18
    layer.masksToBounds = true
    
    addSubview(contentStackView)
    contentStackView.addArrangedSubview(iconImageView)
    contentStackView.addArrangedSubview(titleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentStackView.topAnchor.constraint(equalTo: topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
      contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      contentStackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -16)
    ])
  }
}
