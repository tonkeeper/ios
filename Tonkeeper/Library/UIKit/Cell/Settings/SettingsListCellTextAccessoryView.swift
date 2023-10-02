//
//  SettingsListCellTextAccessoryView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit
import TKUIKit

final class SettingsListCellTextAccessoryView: UIView {
  
  let label = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let text: String
  }
  
  func configure(model: Model) {
    label.text = model.text
    label.attributedText = model.text.attributed(
      with: .label1,
      alignment: .right,
      color: .Accent.blue)
  }
}

private extension SettingsListCellTextAccessoryView {
  func setup() {
    addSubview(label)
    setupConstraints()
  }
  
  func setupConstraints() {
    label.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: topAnchor),
      label.leftAnchor.constraint(equalTo: leftAnchor),
      label.bottomAnchor.constraint(equalTo: bottomAnchor),
      label.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}


