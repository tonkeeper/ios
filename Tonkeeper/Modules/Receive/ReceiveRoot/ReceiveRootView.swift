//
//  ReceiveReceiveView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import UIKit

final class ReceiveRootView: UIView, ConfigurableView {
  
  var imageSize: CGSize {
    .init(width: .logoSide, height: .logoSide)
  }
  
  struct Model {
    let title: NSAttributedString?
    let qrTitle: NSAttributedString?
    let addressTitle: NSAttributedString?
    let address: String?
    let copyButtonTitle: String?
    let shareButtonTitle: String?
  }
  
  let logoImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.tintColor = .white
    imageView.layer.masksToBounds = true
    return imageView
  }()
  
  let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 2
    return label
  }()
  
  let qrTitleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 1
    return label
  }()
  
  let qrImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.layer.masksToBounds = true
    imageView.backgroundColor = .white
    return imageView
  }()
  
  let addressTitleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 1
    return label
  }()
  
  let addressButton: UIButton = {
    let button = ResizableButton(type: .custom)
    button.setTitleColor(.Text.secondary, for: .normal)
    button.setTitleColor(.Text.tertiary, for: .highlighted)
    button.titleLabel?.applyTextStyleFont(.body1)
    button.titleLabel?.numberOfLines = 0
    button.titleLabel?.lineBreakMode = .byWordWrapping
    button.contentHorizontalAlignment = .left
    return button
  }()
  
  let copyButton: TKButton = {
    let button = TKButton(configuration: .button)
    button.iconImageView.image = .Icons.Buttons.Receive.copy
    return button
  }()
  
  let shareButton: TKButton = {
    let button = TKButton(configuration: .button)
    button.iconImageView.image = .Icons.Buttons.Receive.share
    return button
  }()
  
  private let scrollView = NotDelayScrollView()
  private let scrollViewContentView = UIView()
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  private let logoContainer: UIView = {
    let view = UIView()
    return view
  }()
  
  private let qrCodeContainer: UIView = {
    let view = UIView()
    view.backgroundColor = .white
    view.layer.cornerRadius = .innerCornerRadius
    return view
  }()
  
  private let qrCodeSectionBackground: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.content
    view.layer.masksToBounds = true
    view.layer.cornerRadius = .outterCornerRadius
    return view
  }()
  
  private let addressSectionBackground: UIView = {
    let view = UIView()
    view.backgroundColor = .Background.content
    view.layer.masksToBounds = true
    view.layer.cornerRadius = .outterCornerRadius
    return view
  }()
  
  private let buttonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillProportionally
    return stackView
  }()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    logoImageView.layoutIfNeeded()
    logoImageView.layer.cornerRadius = logoImageView.bounds.height / 2
  }
  
  // MARK: - Configurable View
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    qrTitleLabel.attributedText = model.qrTitle
    addressTitleLabel.attributedText = model.addressTitle
    addressButton.setAttributedTitle(
      model.address?.attributed(with: .label1,
                               alignment: .left,
                               lineBreakMode: .byCharWrapping,
                               color: .Text.secondary
                              ), for: .normal
    )
    addressButton.setAttributedTitle(
      model.address?.attributed(with: .label1,
                               alignment: .left,
                               lineBreakMode: .byCharWrapping,
                               color: .Text.tertiary
                              ), for: .highlighted
    )
    copyButton.title = model.copyButtonTitle
    shareButton.title = model.shareButtonTitle
  }
}

// MARK: - Private

private extension ReceiveRootView {
  func setup() {
    backgroundColor = .Background.page
    
    scrollView.contentInsetAdjustmentBehavior = .never
    
    addSubview(scrollView)
    scrollView.addSubview(scrollViewContentView)
    scrollViewContentView.addSubview(logoContainer)
    scrollViewContentView.addSubview(titleLabel)
    scrollViewContentView.addSubview(qrCodeSectionBackground)
    scrollViewContentView.addSubview(addressSectionBackground)
    
    logoContainer.addSubview(logoImageView)
    
    qrCodeSectionBackground.addSubview(qrTitleLabel)
    qrCodeSectionBackground.addSubview(qrCodeContainer)
    qrCodeContainer.addSubview(qrImageView)
    
    addressSectionBackground.addSubview(addressTitleLabel)
    addressSectionBackground.addSubview(addressButton)
    addressSectionBackground.addSubview(buttonsStackView)
    addressSectionBackground.addSubview(separatorView)
    
    let verticalSeparator = SpacingView(horizontalSpacing: .constant(.separatorWidth), verticalSpacing: .none)
    verticalSeparator.backgroundColor = .Separator.common
    buttonsStackView.addArrangedSubview(copyButton)
    buttonsStackView.addArrangedSubview(verticalSeparator)
    buttonsStackView.addArrangedSubview(shareButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollViewContentView.translatesAutoresizingMaskIntoConstraints = false
    logoContainer.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    qrCodeSectionBackground.translatesAutoresizingMaskIntoConstraints = false
    qrTitleLabel.translatesAutoresizingMaskIntoConstraints = false
    qrImageView.translatesAutoresizingMaskIntoConstraints = false
    addressSectionBackground.translatesAutoresizingMaskIntoConstraints = false
    addressTitleLabel.translatesAutoresizingMaskIntoConstraints = false
    addressButton.translatesAutoresizingMaskIntoConstraints = false
    buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    qrCodeContainer.translatesAutoresizingMaskIntoConstraints = false
    logoImageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      
      scrollViewContentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      scrollViewContentView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      scrollViewContentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor).withPriority(.defaultHigh),
      scrollViewContentView.rightAnchor.constraint(equalTo: scrollView.rightAnchor).withPriority(.defaultHigh),
      scrollViewContentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).withPriority(.defaultHigh),
      
      logoContainer.topAnchor.constraint(equalTo: scrollViewContentView.topAnchor, constant: .imageTopSpace),
      logoContainer.widthAnchor.constraint(equalToConstant: .logoSide),
      logoContainer.heightAnchor.constraint(equalToConstant: .logoSide),
      logoContainer.centerXAnchor.constraint(equalTo: scrollViewContentView.centerXAnchor),
      
      logoImageView.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
      logoImageView.centerYAnchor.constraint(equalTo: logoContainer.centerYAnchor),
      logoImageView.widthAnchor.constraint(equalToConstant: .logoSide),
      logoImageView.heightAnchor.constraint(equalToConstant: .logoSide),
      
      titleLabel.topAnchor.constraint(equalTo: logoContainer.bottomAnchor, constant: .titleTopSpace),
      titleLabel.centerXAnchor.constraint(equalTo: scrollViewContentView.centerXAnchor),
      
      qrCodeSectionBackground.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: .qrTopSpace),
      qrCodeSectionBackground.leftAnchor.constraint(equalTo: scrollViewContentView.leftAnchor, constant: .contentSideSpace),
      qrCodeSectionBackground.rightAnchor.constraint(equalTo: scrollViewContentView.rightAnchor, constant: -.contentSideSpace),
      
      addressSectionBackground.topAnchor.constraint(equalTo: qrCodeSectionBackground.bottomAnchor, constant: ContentInsets.sideSpace),
      addressSectionBackground.leftAnchor.constraint(equalTo: qrCodeSectionBackground.leftAnchor),
      addressSectionBackground.rightAnchor.constraint(equalTo: qrCodeSectionBackground.rightAnchor),
      addressSectionBackground.bottomAnchor.constraint(equalTo: scrollViewContentView.bottomAnchor, constant: -.addressBottomSpace),
      
      qrTitleLabel.topAnchor.constraint(equalTo: qrCodeSectionBackground.topAnchor, constant: ContentInsets.sideSpace),
      qrTitleLabel.leftAnchor.constraint(equalTo: qrCodeSectionBackground.leftAnchor, constant: ContentInsets.sideSpace),
      qrTitleLabel.rightAnchor.constraint(equalTo: qrCodeSectionBackground.rightAnchor, constant: -ContentInsets.sideSpace),
      qrCodeContainer.topAnchor.constraint(equalTo: qrTitleLabel.bottomAnchor, constant: ContentInsets.sideSpace),
      qrCodeContainer.leftAnchor.constraint(equalTo: qrCodeSectionBackground.leftAnchor, constant: ContentInsets.sideSpace),
      qrCodeContainer.rightAnchor.constraint(equalTo: qrCodeSectionBackground.rightAnchor, constant: -ContentInsets.sideSpace),
      qrCodeContainer.bottomAnchor.constraint(equalTo: qrCodeSectionBackground.bottomAnchor, constant: -ContentInsets.sideSpace),
      qrCodeContainer.heightAnchor.constraint(equalTo: qrCodeContainer.widthAnchor),
      qrImageView.topAnchor.constraint(equalTo: qrCodeContainer.topAnchor, constant: .qrCodeSideSpace),
      qrImageView.leftAnchor.constraint(equalTo: qrCodeContainer.leftAnchor, constant: .qrCodeSideSpace),
      qrImageView.bottomAnchor.constraint(equalTo: qrCodeContainer.bottomAnchor, constant: -.qrCodeSideSpace),
      qrImageView.rightAnchor.constraint(equalTo: qrCodeContainer.rightAnchor, constant: -.qrCodeSideSpace),
      
      addressTitleLabel.topAnchor.constraint(equalTo: addressSectionBackground.topAnchor, constant: ContentInsets.sideSpace),
      addressTitleLabel.leftAnchor.constraint(equalTo: addressSectionBackground.leftAnchor, constant: ContentInsets.sideSpace),
      addressTitleLabel.rightAnchor.constraint(equalTo: addressSectionBackground.rightAnchor, constant: -ContentInsets.sideSpace),
      addressButton.topAnchor.constraint(equalTo: addressTitleLabel.bottomAnchor, constant: .addressTitleBottomSpace),
      addressButton.leftAnchor.constraint(equalTo: addressTitleLabel.leftAnchor),
      addressButton.rightAnchor.constraint(equalTo: addressTitleLabel.rightAnchor),
      separatorView.topAnchor.constraint(equalTo: addressButton.bottomAnchor, constant: .buttonsTopSpace),
      separatorView.heightAnchor.constraint(equalToConstant: .separatorWidth),
      separatorView.leftAnchor.constraint(equalTo: addressSectionBackground.leftAnchor),
      separatorView.rightAnchor.constraint(equalTo: addressSectionBackground.rightAnchor),
      buttonsStackView.topAnchor.constraint(equalTo: separatorView.bottomAnchor),
      buttonsStackView.leftAnchor.constraint(equalTo: addressSectionBackground.leftAnchor),
      buttonsStackView.rightAnchor.constraint(equalTo: addressSectionBackground.rightAnchor),
      buttonsStackView.bottomAnchor.constraint(equalTo: addressSectionBackground.bottomAnchor),
      buttonsStackView.heightAnchor.constraint(equalToConstant: .buttonsHeight)
    ])
  }
}

private extension CGFloat {
  static let outterCornerRadius: CGFloat = 16
  static let innerCornerRadius: CGFloat = 8
  static let imageTopSpace: CGFloat = 32
  static let logoSide: CGFloat = 72
  static let titleTopSpace: CGFloat = 12
  static let contentSideSpace: CGFloat = 48
  static let qrTopSpace: CGFloat = 24
  static let addressTitleBottomSpace: CGFloat = 2
  static let addressBottomSpace: CGFloat = 53
  static let separatorWidth: CGFloat = 0.5
  static let buttonsTopSpace: CGFloat = 15.5
  static let buttonsHeight: CGFloat = 48
  static let qrCodeSideSpace: CGFloat = 12
}

private extension TKButton.Configuration {
  static var button: TKButton.Configuration {
    .init(type: .secondary,
          size: .small,
          shape: .rect,
          contentInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
  }
}
