//
//  SettingsListCellContentView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit
import TKUIKitLegacy

final class SettingsListCellContentView: UIControlClosure, ContainerCollectionViewCellContent {
  
  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  let accessoryView = SettingsListCellAccessoryView()

  private var isHighlightable = false
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue && isHighlightable else { return }
      didUpdateHightlightState()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: String
    let subtitle: String?
    let accessoryModel: SettingsListCellAccessoryView.Model
    let handler: (() -> Void)?
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.attributed(
      with: .label1,
      alignment: .left,
      color: .Text.primary
    )
    subtitleLabel.attributedText = model.subtitle?.attributed(
      with: .body1,
      alignment: .left,
      color: .Text.secondary
    )
    accessoryView.configure(model: model.accessoryModel)
    isHighlightable = model.handler != nil
    removeActions()
    addAction(.init(handler: {
      model.handler?()
    }), for: .touchUpInside)
  }
  
  func prepareForReuse() {
    titleLabel.attributedText = nil
  }
}

private extension SettingsListCellContentView {
  func setup() {
    addSubview(titleLabel)
    addSubview(subtitleLabel)
    addSubview(accessoryView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    subtitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    accessoryView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: ContentInsets.sideSpace),
      titleLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -ContentInsets.sideSpace)
        .withPriority(.defaultHigh),
      
      subtitleLabel.leftAnchor.constraint(equalTo: titleLabel.rightAnchor, constant: 8),
      subtitleLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
      
      accessoryView.leftAnchor.constraint(greaterThanOrEqualTo: subtitleLabel.rightAnchor),
      accessoryView.topAnchor.constraint(equalTo: topAnchor, constant: ContentInsets.sideSpace),
      accessoryView.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace)
        .withPriority(.defaultHigh),
      accessoryView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -ContentInsets.sideSpace)
        .withPriority(.defaultHigh),
    ])
  }
  
  func didUpdateHightlightState() {
    let duration: TimeInterval = isHighlighted ? 0.05 : 0.2
    
    UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .curveEaseInOut]) {
      self.backgroundColor = self.isHighlighted ? .Background.highlighted : .clear
    }
  }
}
