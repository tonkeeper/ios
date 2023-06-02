//
//  ModalContentListItemView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import UIKit

final class ModalContentListItemView: UIView, ConfigurableView {
  
  let leftLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body1)
    label.textColor = .Text.secondary
    label.textAlignment = .left
    return label
  }()
  
  let rightTopLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.label1)
    label.textColor = .Text.primary
    label.textAlignment = .right
    label.numberOfLines = 0
    return label
  }()
  
  let rightBottomLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.textAlignment = .right
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: ModalContentViewController.Configuration.ListItem) {
    leftLabel.text = model.left
    rightTopLabel.text = model.rightTop
    rightBottomLabel.text = model.rightBottom
  }
}

private extension ModalContentListItemView {
  func setup() {
    leftLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    addSubview(leftLabel)
    addSubview(rightTopLabel)
    addSubview(rightBottomLabel)
    
    leftLabel.translatesAutoresizingMaskIntoConstraints = false
    rightTopLabel.translatesAutoresizingMaskIntoConstraints = false
    rightBottomLabel.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      leftLabel.topAnchor.constraint(equalTo: topAnchor, constant: ContentInsets.sideSpace),
      leftLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      
      rightTopLabel.topAnchor.constraint(equalTo: topAnchor, constant: ContentInsets.sideSpace),
      rightTopLabel.leftAnchor.constraint(equalTo: leftLabel.rightAnchor, constant: .leftRightSpacing),
      rightTopLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      
      rightBottomLabel.topAnchor.constraint(equalTo: rightTopLabel.bottomAnchor),
      rightBottomLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      rightBottomLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -ContentInsets.sideSpace)
    ])
  }
}

private extension CGFloat {
  static let leftRightSpacing: CGFloat = 20
}

