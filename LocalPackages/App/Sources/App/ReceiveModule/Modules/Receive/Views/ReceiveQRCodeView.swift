import UIKit
import TKUIKit

final class ReceiveQRCodeView: UIView {
  
  var tagString: String? {
    didSet {
      if let tagString {
        tagView.configure(
          configuration: TKUITagView.Configuration(
            text: tagString,
            textColor: .black,
            backgroundColor: .Accent.orange
          )
        )
        addressButtonBottomConstraint.isActive = false
        addressButtonBottomTagConstraint.isActive = true
      } else {
        addressButtonBottomTagConstraint.isActive = false
        addressButtonBottomConstraint.isActive = true
      }
    }
  }
  
  let contentContainer = UIView()
  let qrCodeImageView = UIImageView()
  let addressButton = ReceiveAddressButton()
  let tokenImageView = UIImageView()
  let tagView = TKUITagView()
  
  private lazy var addressButtonBottomConstraint: NSLayoutConstraint = {
    addressButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
  }()
  private lazy var addressButtonBottomTagConstraint: NSLayoutConstraint = {
    addressButton.bottomAnchor.constraint(equalTo: tagView.topAnchor, constant: -12)
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension ReceiveQRCodeView {
  func setup() {
    backgroundColor = .white
    layer.cornerRadius = 20
    layer.masksToBounds = true
    
    tokenImageView.backgroundColor = .white
    tokenImageView.contentMode = .center

    addSubview(contentContainer)
    contentContainer.addSubview(qrCodeImageView)
    contentContainer.addSubview(addressButton)
    contentContainer.addSubview(tagView)
    qrCodeImageView.addSubview(tokenImageView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    qrCodeImageView.translatesAutoresizingMaskIntoConstraints = false
    addressButton.translatesAutoresizingMaskIntoConstraints = false
    tokenImageView.translatesAutoresizingMaskIntoConstraints = false
    tagView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentContainer.topAnchor.constraint(equalTo: topAnchor, constant: .containerPadding),
      contentContainer.leftAnchor.constraint(equalTo: leftAnchor, constant: .containerPadding),
      contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.containerPadding),
      contentContainer.rightAnchor.constraint(equalTo: rightAnchor, constant: -.containerPadding),
      
      tagView.centerXAnchor.constraint(equalTo: centerXAnchor),
      tagView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
      
      addressButton.leftAnchor.constraint(equalTo: contentContainer.leftAnchor),
      addressButton.rightAnchor.constraint(equalTo: contentContainer.rightAnchor),
      addressButton.topAnchor.constraint(equalTo: qrCodeImageView.bottomAnchor, constant: .addressTopInset),
      
      qrCodeImageView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
      qrCodeImageView.leftAnchor.constraint(equalTo: contentContainer.leftAnchor),
      qrCodeImageView.rightAnchor.constraint(equalTo: contentContainer.rightAnchor),
      qrCodeImageView.widthAnchor.constraint(equalTo: qrCodeImageView.heightAnchor),
      
      tokenImageView.widthAnchor.constraint(equalToConstant: .tokenImageSide),
      tokenImageView.heightAnchor.constraint(equalToConstant: .tokenImageSide),
      tokenImageView.centerXAnchor.constraint(equalTo: qrCodeImageView.centerXAnchor),
      tokenImageView.centerYAnchor.constraint(equalTo: qrCodeImageView.centerYAnchor),
    ])
  }
}

private extension CGFloat {
  static let containerPadding: CGFloat = 24
  static let addressTopInset: CGFloat = 12
  static let tokenImageSide: CGFloat = 64
}
