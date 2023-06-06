//
//  WalletRootView.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit

final class WalletRootView: UIView {
  
  private let contentContainer = UIView()
  
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
}

private extension WalletRootView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(contentContainer)
    
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      contentContainer.leftAnchor.constraint(equalTo: leftAnchor),
      contentContainer.rightAnchor.constraint(equalTo: rightAnchor),
      contentContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
    ])
  }
}
