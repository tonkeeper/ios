//
//  BalanceCellContentView.swift
//  Tonkeeper
//
//  Created by Grigory on 12.8.23..
//

import UIKit

final class BalanceCellContentView: UIView, ContainerCollectionViewCellContent {
  
  // MARK: - ImageLoader
  
  weak var imageLoader: ImageLoader? {
    didSet {
      defaultCellContentView.imageLoader = imageLoader
    }
  }
  
  // MARK: - Subviews
  
  let defaultCellContentView = DefaultCellContentView()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let contentViewSize = CGSize(width: bounds.width - ContentInsets.sideSpace * 2,
                                 height: max(0, bounds.height - ContentInsets.sideSpace * 2))
    defaultCellContentView.frame.size = contentViewSize
    defaultCellContentView.frame.origin = CGPoint(x: ContentInsets.sideSpace,
                                                  y: ContentInsets.sideSpace)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let contentViewSize = CGSize(width: size.width - ContentInsets.sideSpace * 2,
                                 height: max(0, size.height - ContentInsets.sideSpace * 2))
    let defaultContentHeight = defaultCellContentView.sizeThatFits(contentViewSize).height
    return CGSize(width: size.width, height: defaultContentHeight + ContentInsets.sideSpace * 2)
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let defaultContentModel: DefaultCellContentView.Model
  }
  
  func configure(model: Model) {
    defaultCellContentView.configure(model: model.defaultContentModel)
    setNeedsLayout()
  }
  
  // MARK: - ContainerCollectionViewCellContent
  
  func prepareForReuse() {
    defaultCellContentView.prepareForReuse()
  }
}

private extension BalanceCellContentView {
  func setup() {
    isUserInteractionEnabled = false
    addSubview(defaultCellContentView)
  }
}
