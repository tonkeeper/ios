import UIKit
import TKUIKitLegacy

final class WalletHeaderBannerView: UIView, ConfigurableView {
  
  var didTapCloseButton: (() -> Void)?
  
  private let containerView = UIView()
  private let titleLabel = UILabel()
  private let descriptionLabel = UILabel()
  private let closeButton: UIButton = {
    let button = IncreaseTapAreaUIButton(type: .system)
    button.tapAreaInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
    button.setImage(.Icons.Buttons.Header.close, for: .normal)
    return button
  }()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  func configure(model: WalletHeaderBannerModel) {
    containerView.backgroundColor = model.appearance.backgroundColor
    titleLabel.attributedText = model.title.attributed(
      with: .label1,
      alignment: .left,
      color: model.appearance.tintColor)
    descriptionLabel.attributedText = model.description?.attributed(
      with: .body2,
      alignment: .left,
      color: model.appearance.descriptionColor)
    closeButton.tintColor = model.appearance.tintColor
  }
}

private extension WalletHeaderBannerView {
  func setup() {
    containerView.layer.cornerRadius = 16
    descriptionLabel.numberOfLines = 0
    
    closeButton.addAction(UIAction(handler: { [weak self] _ in
      self?.didTapCloseButton?()
    }), for: .touchUpInside)
    
    addSubview(containerView)
    containerView.addSubview(titleLabel)
    containerView.addSubview(descriptionLabel)
    containerView.addSubview(closeButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    containerView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    
    closeButton.setContentHuggingPriority(.required, for: .horizontal)
    
    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: topAnchor),
      containerView.leftAnchor.constraint(equalTo: leftAnchor, constant: .containerPadding),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.containerPadding),
      containerView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.containerPadding),
      
      titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: UIEdgeInsets.contentPadding.top),
      titleLabel.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: UIEdgeInsets.contentPadding.left),
      
      closeButton.leftAnchor.constraint(equalTo: titleLabel.rightAnchor),
      closeButton.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -UIEdgeInsets.contentPadding.right),
      closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
      
      descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
      descriptionLabel.leftAnchor.constraint(equalTo: titleLabel.leftAnchor),
      descriptionLabel.rightAnchor.constraint(equalTo: closeButton.rightAnchor),
      descriptionLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -UIEdgeInsets.contentPadding.bottom)
    ])
  }
}

private extension CGFloat {
  static let containerPadding: CGFloat = 16
}

private extension UIEdgeInsets {
  static let contentPadding = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
}
