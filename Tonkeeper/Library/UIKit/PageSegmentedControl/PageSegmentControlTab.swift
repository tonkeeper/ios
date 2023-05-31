//
//  PageSegmentControlTab.swift
//  Tonkeeper
//
//  Created by Grigory on 30.5.23..
//

import UIKit

final class PageSegmentControlTab: UIControlClosure, ConfigurableView {
  
  override var isSelected: Bool {
    didSet {
      label.textColor = isSelected ? .Text.primary : .Text.secondary
    }
  }
  
  private let label: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.label1)
    label.textColor = .Text.primary
    label.textAlignment = .center
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: String?) {
    label.text = model
  }
}

private extension PageSegmentControlTab {
  func setup() {
    addSubview(label)
    
    label.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: topAnchor, constant: UIEdgeInsets.insets.top),
      label.leftAnchor.constraint(equalTo: leftAnchor, constant: UIEdgeInsets.insets.left),
      label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -UIEdgeInsets.insets.bottom)
        .withPriority(.defaultHigh),
      label.rightAnchor.constraint(equalTo: rightAnchor, constant: -UIEdgeInsets.insets.right)
        .withPriority(.defaultHigh)
    ])
  }
}

private extension UIEdgeInsets {
  static let insets: UIEdgeInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
}
