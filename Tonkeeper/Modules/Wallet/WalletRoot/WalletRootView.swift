//
//  WalletRootView.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit

final class WalletRootView: UIView, ConfigurableView {
  
  private let contentContainer = UIView()
  let setupWalletButton = TKButton(configuration: .primaryLarge)
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func addContent(contentView: UIView) {
    contentContainer.addSubview(contentView)
    
    contentView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
      contentView.leftAnchor.constraint(equalTo: contentContainer.leftAnchor),
      contentView.rightAnchor.constraint(equalTo: contentContainer.rightAnchor),
      contentView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
    ])
  }
  
  // MARK: - ConfigurableView

  struct Model {
    let setupWalletButtonTitle: String
    let isSetupWalletButtonHidden: Bool
  }
  
  func configure(model: Model) {
    setupWalletButton.title = model.setupWalletButtonTitle
    setupWalletButton.isHidden = model.isSetupWalletButtonHidden
  }
}

private extension WalletRootView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(contentContainer)
    addSubview(setupWalletButton)
    
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    setupWalletButton.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      contentContainer.leftAnchor.constraint(equalTo: leftAnchor),
      contentContainer.rightAnchor.constraint(equalTo: rightAnchor),
      contentContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      
      setupWalletButton.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      setupWalletButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      setupWalletButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -.setupWalletButtonBottomSpace)
    ])
  }
}

private extension CGFloat {
  static let setupWalletButtonBottomSpace: CGFloat = 16
}
