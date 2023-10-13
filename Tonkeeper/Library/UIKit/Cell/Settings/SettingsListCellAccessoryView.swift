//
//  SettingsListCellAccessoryView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit
import TKUIKit

final class SettingsListCellAccessoryView: UIView, ContainerCollectionViewCellContent {
  
  private let containerView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  enum Model {
    case text(SettingsListCellTextAccessoryView.Model)
    case icon(SettingsListCellIconAccessoryView.Model)
    case switchControl(SettingsListCellSwitchAccessoryView.Model)
  }

  func configure(model: Model) {
    let isUserInteractionEnabled: Bool
    containerView.subviews.forEach { $0.removeFromSuperview() }
    let view: UIView
    switch model {
    case .text(let model):
      let textAccessoryView = SettingsListCellTextAccessoryView()
      textAccessoryView.configure(model: model)
      isUserInteractionEnabled = false
      view = textAccessoryView
    case .icon(let model):
      let iconAccessoryView = SettingsListCellIconAccessoryView()
      iconAccessoryView.configure(model: model)
      isUserInteractionEnabled = false
      view = iconAccessoryView
    case .switchControl(let model):
      let switchAccessoryView = SettingsListCellSwitchAccessoryView()
      switchAccessoryView.configure(model: model)
      isUserInteractionEnabled = true
      view = switchAccessoryView
    }
    
    self.isUserInteractionEnabled = isUserInteractionEnabled
    containerView.isUserInteractionEnabled = isUserInteractionEnabled
    view.isUserInteractionEnabled = isUserInteractionEnabled
    
    containerView.addSubview(view)
    
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: containerView.topAnchor),
      view.leftAnchor.constraint(equalTo: containerView.leftAnchor),
      view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
      view.rightAnchor.constraint(equalTo: containerView.rightAnchor)
    ])
  }
  
  func prepareForReuse() {
    containerView.subviews.forEach { $0.removeFromSuperview() }
  }
}

private extension SettingsListCellAccessoryView {
  func setup() {
    addSubview(containerView)
    setupConstraints()
  }
  
  func setupConstraints() {
    containerView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: topAnchor),
      containerView.leftAnchor.constraint(equalTo: leftAnchor),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      containerView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh)
    ])
  }
}

