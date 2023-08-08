//
//  ActivityListSectionHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

final class ActivityListSectionHeaderView: UICollectionReusableView, Reusable, ConfigurableView {
  
  struct Model: Hashable {
    let date: String?
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

private extension ActivityListSectionHeaderView {
  func setup() {
    addSubview(dateLabel)
    backgroundColor = .Background.page
    
    dateLabel.backgroundColor = .Background.page
    
    dateLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      dateLabel.topAnchor.constraint(equalTo: topAnchor),
      dateLabel.leftAnchor.constraint(equalTo: leftAnchor),
      dateLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
      dateLabel.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
