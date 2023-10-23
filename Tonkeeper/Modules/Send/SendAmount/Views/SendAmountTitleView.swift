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
  
  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 4
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
    titleLabel.attributedText = model.title
      .attributed(with: .h3, alignment: .center, color: .Text.primary)
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
