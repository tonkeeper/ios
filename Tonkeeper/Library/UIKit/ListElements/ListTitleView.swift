//
//  ListTitleView.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit

final class ListTitleView: UIView, Reusable, ContainerCollectionViewReusableViewContent {
  
  struct Model: Hashable {
    let date: String?
  }
  
  private let dateLabel: UILabel = {
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
    dateLabel.text = nil
  }
  
  func configure(model: Model) {
    dateLabel.text = model.date
  }
}

private extension ListTitleView {
  func setup() {
    addSubview(dateLabel)
    backgroundColor = .Background.page
    
    dateLabel.backgroundColor = .Background.page
    
    dateLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      dateLabel.topAnchor.constraint(equalTo: topAnchor),
      dateLabel.leftAnchor.constraint(equalTo: leftAnchor),
      dateLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
      dateLabel.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}

private extension CGFloat {
  static let height: CGFloat = 56
}
