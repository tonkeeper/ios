//
//  HeaderTwoLineTitleView.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import UIKit

final class HeaderTwoLineTitleView: UIView, ConfigurableView {
  
  struct Model {
    let title: String?
    let subtitle: NSAttributedString?
  }
  
  let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h3)
    label.textColor = .Text.primary
    label.textAlignment = .center
    return label
  }()
  
  let subtitleLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    stackView.frame = bounds
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return stackView.systemLayoutSizeFitting(.zero)
  }
  
  override var intrinsicContentSize: CGSize {
    return stackView.systemLayoutSizeFitting(.zero)
  }
  
  func configure(model: Model) {
    titleLabel.text = model.title
    subtitleLabel.attributedText = model.subtitle
    invalidateIntrinsicContentSize()
  }
}

private extension HeaderTwoLineTitleView {
  func setup() {
    addSubview(stackView)
    
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(subtitleLabel)
  }
}
