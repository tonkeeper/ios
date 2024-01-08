import UIKit
import TKUIKit

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
  private let actionButton: UIButton = {
    let button = IncreaseTapAreaUIButton(type: .system)
    button.tapAreaInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
    button.titleLabel?.font = TextStyle.label2.font
    button.setTitle("Install stable version", for: .normal)
    button.setImage(.Icons.Size12.chevronRight, for: .normal)
    button.semanticContentAttribute = .forceRightToLeft
    button.imageEdgeInsets = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
    return button
  }()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .leading
    return stackView
  }()
  private let beforeActionButtonSpacingView = SpacingView(verticalSpacing: .constant(4))
  
  private var closeButtonAction: (() -> Void)?
  
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
    titleLabel.attributedText = model.title?.attributed(
      with: .label1,
      alignment: .left,
      color: model.appearance.tintColor)
    descriptionLabel.attributedText = model.description?.attributed(
      with: .body2,
      alignment: .left,
      color: model.appearance.descriptionColor)
    closeButton.tintColor = model.appearance.tintColor
    
    if let actionButtonModel = model.actionButton {
      actionButton.isHidden = false
      beforeActionButtonSpacingView.isHidden = false
      actionButton.setTitle(actionButtonModel.title, for: .normal)
      actionButton.addAction(UIAction(handler: { _ in
        actionButtonModel.action()
      }), for: .touchUpInside)
      actionButton.tintColor = model.appearance.tintColor
    } else {
      actionButton.isHidden = true
      beforeActionButtonSpacingView.isHidden = true
    }
    
    self.closeButtonAction = model.closeButtonAction
  }
}

private extension WalletHeaderBannerView {
  func setup() {
    containerView.layer.cornerRadius = 16
    descriptionLabel.numberOfLines = 0
    
    closeButton.addAction(UIAction(handler: { [weak self] _ in
      self?.didTapCloseButton?()
      self?.closeButtonAction?()
    }), for: .touchUpInside)
    
    addSubview(containerView)
    containerView.addSubview(stackView)
    containerView.addSubview(closeButton)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(descriptionLabel)
    stackView.addArrangedSubview(beforeActionButtonSpacingView)
    stackView.addArrangedSubview(actionButton)
    setupConstraints()
  }
  
  func setupConstraints() {
    containerView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    
    closeButton.setContentHuggingPriority(.required, for: .horizontal)
    
    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: topAnchor),
      containerView.leftAnchor.constraint(equalTo: leftAnchor, constant: .containerPadding),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
      containerView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.containerPadding),
      
      closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: .containerPadding),
      closeButton.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -UIEdgeInsets.contentPadding.right),
      
      stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: UIEdgeInsets.contentPadding.top),
      stackView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: UIEdgeInsets.contentPadding.left),
      stackView.rightAnchor.constraint(equalTo: closeButton.leftAnchor, constant: 0),
      stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -UIEdgeInsets.contentPadding.bottom)
    ])
  }
}

private extension CGFloat {
  static let containerPadding: CGFloat = 16
}

private extension UIEdgeInsets {
  static let contentPadding = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
}
