//
//  ContainerCollectionViewReusableView.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit

protocol ContainerCollectionViewReusableViewContent: ConfigurableView {
  func prepareForReuse()
}

class ContainerCollectionViewReusableView<ContentView: ContainerCollectionViewReusableViewContent>: UICollectionReusableView, ConfigurableView, Reusable {

  let contentView = ContentView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: ContentView.Model) {
    contentView.configure(model: model)
  }
  
  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
    let cellContentViewSize = contentView.sizeThatFits(.init(width: targetSize.width, height: 0))
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    modifiedAttributes.frame.size = cellContentViewSize
    return modifiedAttributes
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    contentView.frame = bounds
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    contentView.prepareForReuse()
  }
}

private extension ContainerCollectionViewReusableView {
  func setup() {
    backgroundColor = .Background.page
    addSubview(contentView)
  }
}
