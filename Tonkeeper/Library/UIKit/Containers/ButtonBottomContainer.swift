//
//  ButtonBottomContainer.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

final class ButtonBottomContainer: UIView {
  
  let button: UIView
  
  // MARK: - Init
  
  init(button: UIView) {
    self.button = button
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Private

private extension ButtonBottomContainer {
  func setup() {
    backgroundColor = .clear
    addSubview(button)
    
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: topAnchor, constant: UIEdgeInsets.buttonInsets.top),
      button.leftAnchor.constraint(equalTo: leftAnchor, constant: UIEdgeInsets.buttonInsets.left),
      button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -UIEdgeInsets.buttonInsets.bottom),
      button.rightAnchor.constraint(equalTo: rightAnchor, constant: -UIEdgeInsets.buttonInsets.right)
    ])
  }
}

private extension UIEdgeInsets {
  static let buttonInsets: UIEdgeInsets = .init(top: 16, left: 32, bottom: 32, right: 32)
}
