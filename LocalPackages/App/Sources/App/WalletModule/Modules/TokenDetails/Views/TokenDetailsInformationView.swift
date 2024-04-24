import UIKit
import TKUIKit

final class TokenDetailsInformationView: UIView, ConfigurableView {
  
  private let tokenAmountLabel = UILabel()
  private let convertedAmountLabel = UILabel()
  private let imageView = UIImageView()
  
  private let contentView = UIView()
  private let amountStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    enum Image {
      case image(UIImage)
      case asyncImage(ImageDownloadTask)
    }
    let image: Image
    let tokenAmount: NSAttributedString
    let convertedAmount: NSAttributedString?
    
    init(image: Image, 
         tokenAmount: String,
         convertedAmount: String?) {
      self.image = image
      self.tokenAmount = tokenAmount.withTextStyle(
        .h2,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.convertedAmount = convertedAmount?.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    }
  }
  
  func configure(model: Model) {
    switch model.image {
    case .image(let image):
      imageView.image = image
    case .asyncImage(let imageDownloadTask):
      imageDownloadTask.start(
        imageView: imageView,
        size: CGSize(width: .imageViewSide, height: .imageViewSide),
        cornerRadius: .imageViewSide/2
      )
    }
    tokenAmountLabel.attributedText = model.tokenAmount
    convertedAmountLabel.attributedText = model.convertedAmount
  }
}

private extension TokenDetailsInformationView {
  func setup() {
    tokenAmountLabel.minimumScaleFactor = 0.5
    tokenAmountLabel.adjustsFontSizeToFitWidth = true
    
    addSubview(contentView)
    contentView.addSubview(amountStackView)
    contentView.addSubview(imageView)
    amountStackView.addArrangedSubview(tokenAmountLabel)
    amountStackView.addArrangedSubview(convertedAmountLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    amountStackView.translatesAutoresizingMaskIntoConstraints = false
    imageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: topAnchor, constant: UIEdgeInsets.contentPadding.top),
      contentView.leftAnchor.constraint(equalTo: leftAnchor, constant: UIEdgeInsets.contentPadding.left),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -UIEdgeInsets.contentPadding.bottom),
      contentView.rightAnchor.constraint(equalTo: rightAnchor, constant: -UIEdgeInsets.contentPadding.right),
      
      amountStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
      amountStackView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
      amountStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).withPriority(.defaultHigh),
      
      imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
      imageView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
      imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      imageView.leftAnchor.constraint(equalTo: amountStackView.rightAnchor, constant: .imageViewLeftPadding),
      imageView.widthAnchor.constraint(equalToConstant: .imageViewSide),
      imageView.heightAnchor.constraint(equalToConstant: .imageViewSide)
    ])
  }
}

private extension UIEdgeInsets {
  static let contentPadding = UIEdgeInsets(top: 16, left: 28, bottom: 28, right: 28)
}

private extension CGFloat {
  static let imageViewLeftPadding: CGFloat = 16
  static let imageViewSide: CGFloat = 64
  static let separatorHeight: CGFloat = TKUIKit.Constants.separatorWidth
}
