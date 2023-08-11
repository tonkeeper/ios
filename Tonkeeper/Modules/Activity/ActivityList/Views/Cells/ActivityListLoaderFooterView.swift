//
//  ActivityListLoaderFooterView.swift
//  Tonkeeper
//
//  Created by Grigory on 11.8.23..
//

import UIKit

final class ActivityListLoaderFooterView: UICollectionReusableView, Reusable {
  var isLoading = false {
    didSet {
      isLoading ? loaderView.startAnimation() : loaderView.stopAnimation()
      isHidden = !isLoading
    }
  }
  
  private let loaderView = LoaderView(size: .small)
    
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let size = CGSize(width: layoutAttributes.frame.width, height: isLoading ? 20 : 0)
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    modifiedAttributes.frame.size = size
    return modifiedAttributes
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    loaderView.frame = bounds
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    loaderView.stopAnimation()
  }
}

private extension ActivityListLoaderFooterView {
  func setup() {
    addSubview(loaderView)
  }
}

