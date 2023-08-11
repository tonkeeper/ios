//
//  ActivityListShimmerCell.swift
//  Tonkeeper
//
//  Created by Grigory on 11.8.23..
//

import UIKit

final class ActivityListShimmerCell: UICollectionViewCell, Reusable {
  
  private let shimmerView = ShimmerView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    shimmerView.frame = bounds
  }
  
  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let size = CGSize(width: layoutAttributes.frame.width, height: 76)
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    modifiedAttributes.frame.size = size
    return modifiedAttributes
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    shimmerView.startAnimation()
  }
  
  func startAnimation() {
    shimmerView.startAnimation()
  }
}

private extension ActivityListShimmerCell {
  func setup() {
    contentView.addSubview(shimmerView)
    layer.cornerRadius = .cornerRadius
    layer.masksToBounds = true
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
}

