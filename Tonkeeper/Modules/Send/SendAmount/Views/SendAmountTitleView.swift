//
//  SendAmountTitleView.swift
//  Tonkeeper
//
//  Created by Grigory on 1.6.23..
//

import UIKit

final class SendAmountTitleView: UIView, ConfigurableView {
  
  struct Model {
    let title: String
    let subtitle: NSAttributedString
  }
  
  let titleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.h3)
    label.textColor = .Text.primary
    label.textAlignment = .center
    return label
  }()
  
  let subtitleLabel: UILabel = {
    let label = UILabel()
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.textAlignment = .center
    return label
  }()
  
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
  
  func configure(model: Model) {
    titleLabel.text = model.title
    subtitleLabel.attributedText = model.subtitle
  }
}

private extension SendAmountTitleView {
  func setup() {
    addSubview(stackView)
    
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(subtitleLabel)
  }
}
