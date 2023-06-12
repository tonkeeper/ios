//
//  ModalCardHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 8.6.23..
//

import UIKit

final class ModalCardHeaderView: UIView {
  
  let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h3)
    label.textColor = .Text.primary
    return label
  }()
  
  var closeButton: TKButton = {
    let button = TKButton(configuration: .init(type: .secondary,
                                               size: .xsmall,
                                               shape: .circle,
                                               contentInsets: .zero))
    button.icon = .Icons.Buttons.Header.close
    return button
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    .init(width: UIView.noIntrinsicMetric, height: .height)
  }
}

private extension ModalCardHeaderView {
  func setup() {
    addSubview(closeButton)
    addSubview(titleLabel)
    
    closeButton.setContentHuggingPriority(.required, for: .horizontal)
    
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      titleLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
      titleLabel.rightAnchor.constraint(equalTo: closeButton.leftAnchor, constant: -ContentInsets.sideSpace),
      
      closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      closeButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace)
    ])
  }
}

private extension CGFloat {
  static let height: CGFloat = 64
  static let buttonRightSpace: CGFloat = 16
}
