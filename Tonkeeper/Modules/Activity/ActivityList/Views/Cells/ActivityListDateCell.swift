//
//  ActivityListDateCell.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

final class ActivityListDateCell: UICollectionViewCell, Reusable, ConfigurableView {
  
  struct Model: Hashable {
    let id = UUID()
    let date: String
  }
  
  private let dateLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h3)
    label.textColor = .Text.primary
    label.textAlignment = .left
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
  }
  
  func configure(model: Model) {
    dateLabel.text = model.date
  }
}

private extension ActivityListDateCell {
  func setup() {
    contentView.addSubview(dateLabel)
    
    dateLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
      dateLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: ContentInsets.sideSpace),
      dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      dateLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -ContentInsets.sideSpace)
    ])
  }
}
