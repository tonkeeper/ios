//
//  DefaultCellContentView.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import UIKit

final class DefaultCellContentView: UIView, ConfigurableView {
  
  let textContentView = DefaultCellTextContentView()
  let imageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private var contentFrame: CGRect {
    bounds.insetBy(dx: ContentInsets.sideSpace, dy: ContentInsets.sideSpace)
  }
  
  private var textContentFrame: CGRect {
    .init(origin: .init(x: contentFrame.origin.x + .imageViewSide + .imageViewTextSpace, y: contentFrame.minY),
          size: .init(width: contentFrame.width - .imageViewSide - .imageViewTextSpace, height: contentFrame.height))
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let textContentSize = textContentView.sizeThatFits(.init(width: textContentFrame.width, height: 0))
    
    textContentView.frame.origin.x = textContentFrame.minX
    textContentView.frame.origin.y = bounds.height / 2 - textContentSize.height/2
    textContentView.frame.size = textContentSize
    
    imageView.frame.size = .init(width: .imageViewSide, height: .imageViewSide)
    imageView.frame.origin.x = contentFrame.minX
    imageView.center.y = textContentView.center.y
    
    imageView.layer.cornerRadius = .imageViewSide/2
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let textContentWidth = size.width - .imageViewSide - .imageViewTextSpace
    let textContentHeight = textContentView.sizeThatFits(.init(width: textContentWidth, height: 0)).height
    return .init(width: size.width, height: textContentHeight + ContentInsets.sideSpace * 2)
  }
  
  func configure(model: Model) {
    textContentView.configure(model: model.textContentModel)
    imageView.image = model.image
    setNeedsLayout()
  }
}

private extension DefaultCellContentView {
  func setup() {
    backgroundColor = .Background.content
    
    imageView.contentMode = .center
    
    addSubview(imageView)
    addSubview(textContentView)
    
    imageView.backgroundColor = .Accent.blue
  }
}

private extension CGFloat {
  static let imageViewSide: CGFloat = 44
  static let imageViewTextSpace: CGFloat = 16
}
