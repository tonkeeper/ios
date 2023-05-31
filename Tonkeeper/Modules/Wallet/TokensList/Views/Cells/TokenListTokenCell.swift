//
//  TokenListTokenCell.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import UIKit

final class TokenListTokenCell: UICollectionViewCell, Reusable, ConfigurableView {
  struct Model: Hashable {
    let id = UUID()
    let title: String
    let shortTitle: String?
    let price: String?
    let priceDiff: NSAttributedString?
    let amount: String
    let fiatAmount: String?
  }
  
  private let textContainerView = TextContainerView()
  private let iconImageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    
    iconImageView.image = nil
    textContainerView.leftVerticalStackView.bottomLeftHorizontalStackView.leftLabel.text = nil
    textContainerView.leftVerticalStackView.bottomLeftHorizontalStackView.rightLabel.text = nil
    textContainerView.leftVerticalStackView.topLeftHorizontalStackView.leftLabel.text = nil
    textContainerView.leftVerticalStackView.topLeftHorizontalStackView.rightLabel.text = nil
    textContainerView.rightVerticalStackView.bottomLabel.text = nil
    textContainerView.rightVerticalStackView.topLabel.text = nil
  }
  
  func configure(model: Model) {
    textContainerView.rightVerticalStackView.topLabel.text = model.amount
    textContainerView.rightVerticalStackView.bottomLabel.text = model.fiatAmount
    
    textContainerView.leftVerticalStackView.topLeftHorizontalStackView.leftLabel.text = model.title
    textContainerView.leftVerticalStackView.topLeftHorizontalStackView.rightLabel.text = model.shortTitle
    
    textContainerView.leftVerticalStackView.bottomLeftHorizontalStackView.leftLabel.text = model.price
    textContainerView.leftVerticalStackView.bottomLeftHorizontalStackView.rightLabel.attributedText = model.priceDiff
  }
}

private extension TokenListTokenCell {
  func setup() {
    layer.masksToBounds = true
    layer.cornerRadius = .cornerRadius
    
    contentView.backgroundColor = .Background.content
    textContainerView.backgroundColor = .Background.content
    
    contentView.addSubview(textContainerView)
    contentView.addSubview(iconImageView)
    
    textContainerView.translatesAutoresizingMaskIntoConstraints = false
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      textContainerView.topAnchor.constraint(equalTo: topAnchor, constant: UIEdgeInsets.contentInsets.top),
      textContainerView.rightAnchor.constraint(equalTo: rightAnchor, constant: -UIEdgeInsets.contentInsets.right),
      textContainerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -UIEdgeInsets.contentInsets.bottom),
      textContainerView.leftAnchor.constraint(equalTo: iconImageView.rightAnchor, constant: .spaceBetweenTextAndIcon),
      
      iconImageView.leftAnchor.constraint(equalTo: leftAnchor, constant: UIEdgeInsets.contentInsets.left),
      iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
      iconImageView.widthAnchor.constraint(equalToConstant: .iconSide),
      iconImageView.heightAnchor.constraint(equalToConstant: .iconSide)
    ])
  }
}

private final class TextContainerView: UIView {
  let rightVerticalStackView = RightVerticalStackView()
  let leftVerticalStackView = LeftVerticalStackView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    rightVerticalStackView.backgroundColor = .Background.content
    leftVerticalStackView.backgroundColor = .Background.content
    
    addSubview(rightVerticalStackView)
    addSubview(leftVerticalStackView)
    
    rightVerticalStackView.setContentHuggingPriority(.required, for: .horizontal)
    leftVerticalStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    
    rightVerticalStackView.translatesAutoresizingMaskIntoConstraints = false
    leftVerticalStackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      rightVerticalStackView.rightAnchor.constraint(equalTo: rightAnchor),
      rightVerticalStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
      
      leftVerticalStackView.rightAnchor.constraint(equalTo: rightVerticalStackView.leftAnchor),
      leftVerticalStackView.leftAnchor.constraint(equalTo: leftAnchor),
      leftVerticalStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
}

private final class RightVerticalStackView: UIView {
  let topLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .Background.content
    label.applyTextStyleFont(.label1)
    label.textColor = .Text.primary
    label.numberOfLines = 1
    label.textAlignment = .right
    return label
  }()
  
  let bottomLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .Background.content
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.numberOfLines = 1
    label.textAlignment = .right
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(topLabel)
    addSubview(bottomLabel)
    
    topLabel.setContentHuggingPriority(.required, for: .horizontal)
    topLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    bottomLabel.setContentHuggingPriority(.required, for: .horizontal)
    bottomLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    topLabel.translatesAutoresizingMaskIntoConstraints = false
    bottomLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      topLabel.topAnchor.constraint(equalTo: topAnchor),
      topLabel.leftAnchor.constraint(equalTo: leftAnchor),
      topLabel.rightAnchor.constraint(equalTo: rightAnchor),
      bottomLabel.topAnchor.constraint(equalTo: topLabel.bottomAnchor),
      bottomLabel.leftAnchor.constraint(equalTo: leftAnchor),
      bottomLabel.rightAnchor.constraint(equalTo: rightAnchor),
      bottomLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private final class LeftVerticalStackView: UIView {
  let topLeftHorizontalStackView = TopLeftHorizontalStackView()
  let bottomLeftHorizontalStackView = BottomLeftHorizontalStackView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    topLeftHorizontalStackView.backgroundColor = .Background.content
    bottomLeftHorizontalStackView.backgroundColor = .Background.content
    
    addSubview(topLeftHorizontalStackView)
    addSubview(bottomLeftHorizontalStackView)
    
    topLeftHorizontalStackView.translatesAutoresizingMaskIntoConstraints = false
    bottomLeftHorizontalStackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      topLeftHorizontalStackView.topAnchor.constraint(equalTo: topAnchor),
      topLeftHorizontalStackView.leftAnchor.constraint(equalTo: leftAnchor),
      topLeftHorizontalStackView.rightAnchor.constraint(equalTo: rightAnchor),
      
      bottomLeftHorizontalStackView.topAnchor.constraint(equalTo: topLeftHorizontalStackView.bottomAnchor),
      bottomLeftHorizontalStackView.leftAnchor.constraint(equalTo: leftAnchor),
      bottomLeftHorizontalStackView.rightAnchor.constraint(equalTo: rightAnchor),
      bottomLeftHorizontalStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private final class TopLeftHorizontalStackView: UIView {
  let leftLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .Background.content
    label.applyTextStyleFont(.label1)
    label.textColor = .Text.primary
    label.numberOfLines = 1
    label.textAlignment = .left
    return label
  }()
  
  let rightLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .Background.content
    label.applyTextStyleFont(.label1)
    label.textColor = .Text.tertiary
    label.numberOfLines = 1
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
  
  private func setup() {
    addSubview(leftLabel)
    addSubview(rightLabel)
    
    leftLabel.setContentHuggingPriority(.required, for: .horizontal)
    
    leftLabel.translatesAutoresizingMaskIntoConstraints = false
    rightLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      leftLabel.topAnchor.constraint(equalTo: topAnchor),
      leftLabel.leftAnchor.constraint(equalTo: leftAnchor),
      leftLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      rightLabel.topAnchor.constraint(equalTo: topAnchor),
      rightLabel.leftAnchor.constraint(equalTo: leftLabel.rightAnchor, constant: .labelTopContainerSpace),
      rightLabel.rightAnchor.constraint(equalTo: rightAnchor),
      rightLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private final class BottomLeftHorizontalStackView: UIView {
  let leftLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .Background.content
    label.applyTextStyleFont(.body2)
    label.textColor = .Text.secondary
    label.numberOfLines = 1
    label.textAlignment = .left
    return label
  }()
  
  let rightLabel: UILabel = {
    let label = UILabel()
    label.backgroundColor = .Background.content
    label.applyTextStyleFont(.body2)
    label.textColor = .Accent.green
    label.numberOfLines = 1
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
  
  private func setup() {
    addSubview(leftLabel)
    addSubview(rightLabel)
    
    leftLabel.setContentHuggingPriority(.required, for: .horizontal)
    
    leftLabel.translatesAutoresizingMaskIntoConstraints = false
    rightLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      leftLabel.topAnchor.constraint(equalTo: topAnchor),
      leftLabel.leftAnchor.constraint(equalTo: leftAnchor),
      leftLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      rightLabel.topAnchor.constraint(equalTo: topAnchor),
      rightLabel.leftAnchor.constraint(equalTo: leftLabel.rightAnchor, constant: .labelBottomContainerSpace),
      rightLabel.rightAnchor.constraint(equalTo: rightAnchor),
      rightLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private extension UIEdgeInsets {
  static let contentInsets: UIEdgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
}

private extension CGFloat {
  static let iconSide: CGFloat = 44
  static let spaceBetweenTextAndIcon: CGFloat = 16
  static let labelTopContainerSpace: CGFloat = 4
  static let labelBottomContainerSpace: CGFloat = 6
  static let cornerRadius: CGFloat = 16
}
