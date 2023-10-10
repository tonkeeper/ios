//
//  SettingsListCellSwitchAccessoryView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit
import TKUIKit

final class SettingsListCellSwitchAccessoryView: UIView {
  
  let switchControl: UISwitch = {
    let control = UISwitch()
    control.onTintColor = .Accent.blue
    return control
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let isOn: Bool
    let isEnabled: Bool
    let handler: (Bool) -> Bool
  }
  
  func configure(model: Model) {
    switchControl.isOn = model.isOn
    switchControl.isEnabled = model.isEnabled
    switchControl.addAction(.init(handler: { [weak self] action in
      guard let self = self else { return }
      if !model.handler(self.switchControl.isOn) {
        self.switchControl.setOn(!self.switchControl.isOn, animated: true)
      }
    }), for: .valueChanged)
  }
}

private extension SettingsListCellSwitchAccessoryView {
  func setup() {
    addSubview(switchControl)
    setupConstraints()
  }
  
  func setupConstraints() {
    switchControl.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      switchControl.topAnchor.constraint(equalTo: topAnchor),
      switchControl.leftAnchor.constraint(equalTo: leftAnchor),
      switchControl.bottomAnchor.constraint(equalTo: bottomAnchor),
      switchControl.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}

private extension CGFloat {
  static let imageSide: CGFloat = 28
}




