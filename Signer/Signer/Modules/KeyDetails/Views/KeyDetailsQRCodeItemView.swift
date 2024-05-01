import UIKit
import TKUIKit

final class KeyDetailsQRCodeItemView: UIView, GenericCollectionViewCellContentView, ReusableView, ConfigurableView {
  
  var padding: NSDirectionalEdgeInsets = .zero
  
  private let imageView = UIImageView()
  private let qrCodeGenerator = QRCodeGeneratorImplementation()
  private var url: URL?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return CGSize(width: size.width, height: size.width)
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let url: URL?
  }
  
  func configure(model: Model) {
    imageView.image = nil
    self.url = model.url
    setNeedsLayout()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    guard let url = url else { return }
    let size = CGSize(width: bounds.width - 48, height: bounds.height - 48)
    Task {
      let image = await qrCodeGenerator.generate(string: url.absoluteString, size: size)
      await MainActor.run {
        imageView.image = image
      }
    }
  }
}

private extension KeyDetailsQRCodeItemView {
  func setup() {
    backgroundColor = .white
    
    addSubview(imageView)
    setupConstraints()
  }
  
  func setupConstraints() {
    imageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: topAnchor, constant: 24),
      imageView.leftAnchor.constraint(equalTo: leftAnchor, constant: 24),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
      imageView.rightAnchor.constraint(equalTo: rightAnchor, constant: -24)
    ])
  }
}
