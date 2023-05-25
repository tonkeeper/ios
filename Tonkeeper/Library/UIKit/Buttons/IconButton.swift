//
//  IconButton.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

final class IconButton: UIControl {
  
  let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.label3)
    label.textColor = .Text.secondary
    label.numberOfLines = 1
    label.textAlignment = .center
    return label
  }()
  
  let button = Button(configuration: .icon)

  override var isHighlighted: Bool {
    didSet {
      button.isHighlighted = isHighlighted
      updateTitleColor()
    }
  }
  
  override var isEnabled: Bool {
    didSet {
      button.isEnabled = isEnabled
      updateTitleColor()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension IconButton {
  func setup() {
    addSubview(button)
    addSubview(titleLabel)
    
    button.isUserInteractionEnabled = false
    
    button.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: topAnchor, constant: .iconTopSpace),
      button.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor, constant: .iconSideSpace),
      button.rightAnchor.constraint(greaterThanOrEqualTo: rightAnchor, constant: -.iconSideSpace),
      
      titleLabel.topAnchor.constraint(equalTo: button.bottomAnchor, constant: .titleTopSpace),
      titleLabel.leftAnchor.constraint(equalTo: leftAnchor),
      titleLabel.rightAnchor.constraint(equalTo: rightAnchor),
      titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.titleBottomSpace)
    ])
  }
  
  func updateTitleColor() {
    titleLabel.textColor = state == .highlighted ? .Text.primary : .Text.secondary
  }
}

private extension CGFloat {
  static let iconTopSpace: CGFloat = 8
  static let iconSideSpace: CGFloat = 14
  static let titleTopSpace: CGFloat = 8
  static let titleBottomSpace: CGFloat = 8
}
