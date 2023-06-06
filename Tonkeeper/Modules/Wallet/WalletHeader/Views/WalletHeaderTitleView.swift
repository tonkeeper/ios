//
//  WalletHeaderTitleView.swift
//  Tonkeeper
//
//  Created by Grigory on 30.5.23..
//

import UIKit

final class WalletHeaderTitleView: UIView {

  private enum Size {
    case compact
    case large
    
    var height: CGFloat {
      switch self {
      case .compact: return .compactHeight
      case .large: return .largeHeight
      }
    }
  }
  
  private var size: Size = .compact {
    didSet {
      guard size != oldValue else { return }
      invalidateIntrinsicContentSize()
    }
  }

  private let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h3)
    label.textColor = .Text.primary
    label.text = "Wallet"
    return label
  }()
  
  let scanQRButton: UIButton = {
    let button = UIButton(type: .system)
    button.setImage(.Icons.Buttons.scanQR, for: .normal)
    button.tintColor = .Accent.blue
    return button
  }()
  
  private let safeAreaView = UIView()
  private let contentView = UIView()
  
  private var contentViewHeightConstraint: NSLayoutConstraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  override var intrinsicContentSize: CGSize {
    let height = size.height + safeAreaInsets.top
    return .init(width: UIView.noIntrinsicMetric,
                 height: height)
  }
  
  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    invalidateIntrinsicContentSize()
  }
}

private extension WalletHeaderTitleView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(contentView)
    contentView.addSubview(titleLabel)
    contentView.addSubview(scanQRButton)
    
    contentView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    scanQRButton.translatesAutoresizingMaskIntoConstraints = false
    safeAreaView.translatesAutoresizingMaskIntoConstraints = false
    
    contentViewHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: size.height)
    contentViewHeightConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      contentView.leftAnchor.constraint(equalTo: leftAnchor),
      contentView.rightAnchor.constraint(equalTo: rightAnchor),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

      scanQRButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      scanQRButton.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -.scanQRButtonRightSpace),
    ])
  }
}

private extension CGFloat {
  static let scanQRButtonRightSpace: CGFloat = 18
  static let largeHeight: CGFloat = 84
  static let compactHeight: CGFloat = 64
}

