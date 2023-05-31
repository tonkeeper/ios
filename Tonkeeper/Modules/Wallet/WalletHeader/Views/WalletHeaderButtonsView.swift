//
//  WalletHeaderButtonsView.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

final class WalletHeaderButtonsView: UIView {
  
  var buttons = [IconButton]() {
    didSet {
      reloadButtons()
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension WalletHeaderButtonsView {
  func setup() {
    stackView.distribution = .fillEqually
    
    addSubview(stackView)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
  
  func reloadButtons() {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    buttons.forEach { stackView.addArrangedSubview($0) }
  }
}
