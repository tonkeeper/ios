//
//  ActivityListSectionShimmerView.swift
//  Tonkeeper
//
//  Created by Grigory on 11.8.23..
//

import UIKit

final class ActivityListSectionShimmerView: UICollectionReusableView, Reusable {
  
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
    shimmerView.frame = CGRect(x: 0, y: 0, width: 100, height: 28)
  }
  
  func startAnimation() {
    shimmerView.startAnimation()
  }
}

private extension ActivityListSectionShimmerView {
  func setup() {
    addSubview(shimmerView)
    layer.cornerRadius = .cornerRadius
    layer.masksToBounds = true
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
}
