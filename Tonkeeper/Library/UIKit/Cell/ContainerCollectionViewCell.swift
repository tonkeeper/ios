//
//  ContainerCollectionViewCell.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

protocol ContainerCollectionViewCellContent: ConfigurableView {
  func prepareForReuse()
}

class ContainerCollectionViewCell<CellContentView: ContainerCollectionViewCellContent>: UICollectionViewCell, ConfigurableView {
  
  let cellContentView = CellContentView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: CellContentView.Model) {
    cellContentView.configure(model: model)
  }
  
  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
    let cellContentViewSize = cellContentView.sizeThatFits(.init(width: targetSize.width, height: 0))
    let modifiedAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    modifiedAttributes.frame.size = CGSize(
      width: cellContentViewSize.width + ContentInsets.sideSpace * 2,
      height: cellContentViewSize.height + ContentInsets.sideSpace * 2
    )
    return modifiedAttributes
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    cellContentView.frame = contentView.bounds.insetBy(dx: ContentInsets.sideSpace, dy: ContentInsets.sideSpace)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cellContentView.prepareForReuse()
  }
}

private extension ContainerCollectionViewCell {
  func setup() {
    contentView.addSubview(cellContentView)
  }
}
