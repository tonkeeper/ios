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
    let isLoading: Bool
  }
  
  private let dateLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h3)
    label.textColor = .Text.primary
    label.textAlignment = .left
    return label
  }()
  
  private let shimmerView = ShimmerView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    shimmerView.stopAnimation()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
  }
  
  func configure(model: Model) {
    dateLabel.text = model.date
    model.isLoading ? shimmerView.startAnimation() : shimmerView.stopAnimation()
    shimmerView.isHidden = !model.isLoading
  }
}

private extension ActivityListSectionHeaderView {
  func setup() {
    addSubview(dateLabel)
    addSubview(shimmerView)
    backgroundColor = .Background.page
    
    dateLabel.backgroundColor = .Background.page
    shimmerView.layer.cornerRadius = .cornerRadius
    shimmerView.layer.masksToBounds = true
    
    dateLabel.translatesAutoresizingMaskIntoConstraints = false
    shimmerView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      dateLabel.topAnchor.constraint(equalTo: topAnchor),
      dateLabel.leftAnchor.constraint(equalTo: leftAnchor),
      dateLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
      dateLabel.rightAnchor.constraint(equalTo: rightAnchor),
      
      shimmerView.topAnchor.constraint(equalTo: topAnchor),
      shimmerView.leftAnchor.constraint(equalTo: leftAnchor),
      shimmerView.bottomAnchor.constraint(equalTo: bottomAnchor),
      shimmerView.widthAnchor.constraint(equalToConstant: 120)
    ])
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 8
}
