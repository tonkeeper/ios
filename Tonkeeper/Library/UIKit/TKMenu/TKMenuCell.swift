//
//  TKMenuCell.swift
//  Tonkeeper
//
//  Created by Grigory on 11.7.23..
//

import UIKit
import SwiftUI

final class TKMenuCell: UITableViewCell, ConfigurableView {
  
  let iconImageView = UIImageView()
  let leftLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.label1)
    label.textColor = .Text.primary
    label.numberOfLines = 1
    label.textAlignment = .left
    return label
  }()
  let rightLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body1)
    label.textColor = .Text.secondary
    label.numberOfLines = 1
    label.textAlignment = .left
    return label
  }()
  let tickImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.tintColor = .Accent.blue
    imageView.image = .Icons.TKMenu.tick
    imageView.contentMode = .center
    return imageView
  }()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = .spacing
    stackView.distribution = .fill
    return stackView
  }()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: TKMenuItem) {
    leftLabel.text = model.leftTitle
    rightLabel.text = model.rightTitle
    tickImageView.alpha = model.isSelected ? 1 : 0
  }
}

private extension TKMenuCell {
  func setup() {
    backgroundColor = .Background.contentTint
    
    let selectedBackgroundView = UIView()
    selectedBackgroundView.backgroundColor = .Background.contentAttention
    self.selectedBackgroundView = selectedBackgroundView
    
    contentView.addSubview(stackView)
    stackView.addArrangedSubview(iconImageView)
    stackView.addArrangedSubview(leftLabel)
    stackView.addArrangedSubview(rightLabel)
    stackView.addArrangedSubview(tickImageView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    leftLabel.setContentHuggingPriority(.required, for: .horizontal)
    leftLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    tickImageView.setContentHuggingPriority(.required, for: .horizontal)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    tickImageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
      stackView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: .stackViewSideSpace),
      stackView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -.stackViewSideSpace)
        .withPriority(.defaultHigh),
      stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        .withPriority(.defaultHigh),
      
      iconImageView.widthAnchor.constraint(equalToConstant: .iconSide),
      tickImageView.widthAnchor.constraint(equalToConstant: .tickSide)
    ])
  }
}

private extension CGFloat {
  static let iconSide: CGFloat = 24
  static let tickSide: CGFloat = 16
  static let stackViewSideSpace: CGFloat = 16
  static let spacing: CGFloat = 8
}
