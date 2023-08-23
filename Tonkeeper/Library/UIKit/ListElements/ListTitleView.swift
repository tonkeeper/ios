//
//  ListTitleView.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit

final class ListTitleView: UIView, Reusable, ContainerCollectionViewReusableViewContent {
  
  struct Model: Hashable {
    let title: String?
  }
  
  private let titleLabel: UILabel = {
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
  
  override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return CGSize(width: size.width, height: .height)
  }
  
  func prepareForReuse() {
    titleLabel.text = nil
  }
  
  func configure(model: Model) {
    titleLabel.text = model.title
  }
}

private extension ListTitleView {
  func setup() {
    addSubview(titleLabel)
    backgroundColor = .Background.page
    
    titleLabel.backgroundColor = .Background.page
    
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: topAnchor),
      titleLabel.leftAnchor.constraint(equalTo: leftAnchor),
      titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
      titleLabel.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}

private extension CGFloat {
  static let height: CGFloat = 56
}
