import UIKit
import TKUIKit
import TKCore

final class TonConnectModalHeaderView: UIView, ConfigurableView {
  
  // MARK: - Subviews
  
  private let tonImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.backgroundColor = .Background.content
    imageView.image = .TKUIKit.Images.tonkeeperLogo72
    imageView.tintColor = .Accent.blue
    imageView.contentMode = .scaleAspectFit
    imageView.layer.cornerRadius = .imageCornerRadius
    imageView.layer.masksToBounds = true
    return imageView
  }()
  private let appImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.backgroundColor = .clear
    imageView.layer.cornerRadius = .imageCornerRadius
    imageView.layer.masksToBounds = true
    return imageView
  }()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  private let walletAnimationView = TonConnectHeaderWalletAnimationView()
  
  // MARK: - Image Loader
  
  let imageLoader = ImageLoader()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let walletAddress: String
    let appImage: URL?
  }
  
  func configure(model: Model) {
    walletAnimationView.configure(model: .init(walletAddress: model.walletAddress))
    _ = imageLoader.loadImage(
      url: model.appImage,
      imageView: appImageView
    )
  }
}

private extension TonConnectModalHeaderView {
  func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(tonImageView)
    stackView.addArrangedSubview(walletAnimationView)
    stackView.addArrangedSubview(appImageView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    tonImageView.translatesAutoresizingMaskIntoConstraints = false
    appImageView.translatesAutoresizingMaskIntoConstraints = false
    walletAnimationView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
      
      tonImageView.widthAnchor.constraint(equalToConstant: 72),
      tonImageView.heightAnchor.constraint(equalToConstant: 72),
      
      appImageView.widthAnchor.constraint(equalToConstant: 72),
      appImageView.heightAnchor.constraint(equalToConstant: 72),
      
      walletAnimationView.widthAnchor.constraint(equalToConstant: .animationViewWidth)
    ])
  }
}

private extension CGFloat {
  static let imageCornerRadius: CGFloat = 20
  static let animationViewWidth: CGFloat = 86
}
