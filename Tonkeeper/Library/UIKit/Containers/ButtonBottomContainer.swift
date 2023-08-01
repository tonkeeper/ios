//
//  ButtonBottomContainer.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import UIKit

final class ButtonBottomContainer: UIView {
  
  let button: UIView
  var insets: UIEdgeInsets {
    didSet { didUpdateInsets() }
  }
  
  private var topConstraint: NSLayoutConstraint?
  private var leftConstraint: NSLayoutConstraint?
  private var bottomConstraint: NSLayoutConstraint?
  private var rightConstraint: NSLayoutConstraint?
  
  // MARK: - Init
  
  init(button: UIView, insets: UIEdgeInsets = .buttonInsets) {
    self.button = button
    self.insets = insets
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
    
    topConstraint = button.topAnchor.constraint(equalTo: topAnchor, constant: insets.top)
    leftConstraint = button.leftAnchor.constraint(equalTo: leftAnchor, constant: insets.left)
    bottomConstraint = button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom)
    rightConstraint = button.rightAnchor.constraint(equalTo: rightAnchor, constant: -insets.right)
    
    topConstraint?.isActive = true
    leftConstraint?.isActive = true
    bottomConstraint?.isActive = true
    rightConstraint?.isActive = true
  }
  
  func didUpdateInsets() {
    topConstraint?.constant = insets.top
    leftConstraint?.constant = insets.left
    bottomConstraint?.constant = -insets.bottom
    rightConstraint?.constant = -insets.right
  }
}

private extension UIEdgeInsets {
  static let buttonInsets: UIEdgeInsets = .init(top: 16, left: 32, bottom: 32, right: 32)
}
