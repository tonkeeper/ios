//
//  ActivityListShimmerSectionHeaderView.swift
//  Tonkeeper
//
//  Created by Grigory on 14.8.23..
//

import UIKit

final class ActivityListShimmerSectionHeaderView: UICollectionReusableView, Reusable {
  
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
  
  func startAnimation() {
    shimmerView.startAnimation()
  }
}

private extension ActivityListShimmerSectionHeaderView {
  func setup() {
    addSubview(shimmerView)
    backgroundColor = .Background.page
    
    shimmerView.layer.cornerRadius = .cornerRadius
    shimmerView.layer.masksToBounds = true
    
    shimmerView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      shimmerView.leftAnchor.constraint(equalTo: leftAnchor),
      shimmerView.centerYAnchor.constraint(equalTo: centerYAnchor),
      shimmerView.widthAnchor.constraint(equalToConstant: 120),
      shimmerView.heightAnchor.constraint(equalToConstant: 28)
    ])
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 8
}
