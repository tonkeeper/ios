import UIKit
import TKUIKitLegacy

public final class OpenTransactionTKButtonContentView: UIView, TKButtonContent {

  private let titleLabel = UILabel()
  private let imageView = UIImageView()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: TKButtonContent
  
  public func width(withHeight height: CGFloat) -> CGFloat {
    systemLayoutSizeFitting(CGSize(width: 0, height: height)).width
  }
  
  public func setForegroundColor(_ color: UIColor) {}
  
  // MARK: - ConfigurableView
  
  public struct Model {
    let title: String
    let transactionHash: String
    let image: UIImage?
    
    public init(title: String,
                transactionHash: String,
                image: UIImage?) {
      self.title = title
      self.transactionHash = transactionHash
      self.image = image
    }
  }
  
  public func configure(model: Model) {
    let transaction = model.title.attributed(with: .label2, alignment: .center, color: .Button.primaryForeground)
    let hash = model.transactionHash.attributed(with: .label2, alignment: .center, color: .Text.tertiary)
    let result = NSMutableAttributedString(attributedString: transaction)
    result.append(hash)
    titleLabel.attributedText = result
    imageView.image = model.image
  }
}

private extension OpenTransactionTKButtonContentView {
  func setup() {
    imageView.contentMode = .center
    imageView.tintColor = .Icon.primary
    
    addSubview(imageView)
    addSubview(titleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    imageView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: topAnchor),
      imageView.leftAnchor.constraint(equalTo: leftAnchor),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      
      titleLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor, constant: -1),
      titleLabel.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh),
      titleLabel.leftAnchor.constraint(equalTo: imageView.rightAnchor, constant: 8)
    ])
  }
}
