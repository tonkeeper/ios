//
//  ModalContentListItemView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import UIKit

final class ModalContentListItemView: UIControl, ConfigurableView {
  
  override var isHighlighted: Bool {
    didSet {
      guard isHighlighted != oldValue else { return }
      didUpdateIsHighlighted()
    }
  }
  
  var isSeparatorHidden = false {
    didSet {
      separatorView.isHidden = isSeparatorHidden
    }
  }
  
  private let leftLabel = UILabel()
  
  private let rightTopLabel = UILabel()
  private let rightBottomLabel = UILabel()
  private let rightTopShimmerView = ShimmerView()
  private let rightBottomShimmerView = ShimmerView()
  
  private let rightStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
  private var rightTopShimmerWidthConstraint: NSLayoutConstraint?
  private var rightBottomShimmerWidthConstraint: NSLayoutConstraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: ModalContentViewController.Configuration.ListItem) {
    leftLabel.attributedText = model.left
      .attributed(with: .body1, alignment: .left, color: .Text.secondary)
    
    switch model.rightTop {
    case .value(let value):
      rightTopLabel.attributedText = value.attributed(with: .label1, alignment: .right, color: .Text.primary)
      rightTopLabel.isHidden = false
      rightTopShimmerView.isHidden = true
      rightTopShimmerView.stopAnimation()
      rightTopShimmerWidthConstraint?.isActive = false
    case .loading:
      rightTopLabel.attributedText = nil
      rightTopLabel.isHidden = true
      rightTopShimmerView.isHidden = false
      rightTopShimmerView.startAnimation()
      rightTopShimmerWidthConstraint?.isActive = true
    }
    
    switch model.rightBottom {
    case .value(let value):
      rightBottomLabel.attributedText = value?.attributed(with: .label2, alignment: .right, color: .Text.secondary)
      rightBottomLabel.isHidden = false
      rightBottomShimmerView.isHidden = true
      rightBottomShimmerView.stopAnimation()
      rightBottomShimmerWidthConstraint?.isActive = false
    case .loading:
      rightBottomLabel.attributedText = nil
      rightBottomLabel.isHidden = true
      rightBottomShimmerView.isHidden = false
      rightBottomShimmerView.startAnimation()
      rightBottomShimmerWidthConstraint?.isActive = true
    }
  }
}

private extension ModalContentListItemView {
  func setup() {
    didUpdateIsHighlighted()
    
    addSubview(leftLabel)
    addSubview(rightStackView)
    addSubview(separatorView)
    
    rightStackView.addArrangedSubview(rightTopLabel)
    rightStackView.addArrangedSubview(rightBottomLabel)
    rightStackView.addArrangedSubview(rightTopShimmerView)
    rightStackView.addArrangedSubview(rightBottomShimmerView)
    
    rightStackView.setCustomSpacing(4, after: rightTopShimmerView)
    
    leftLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    leftLabel.translatesAutoresizingMaskIntoConstraints = false
    rightTopShimmerView.translatesAutoresizingMaskIntoConstraints = false
    rightBottomShimmerView.translatesAutoresizingMaskIntoConstraints = false
    rightStackView.translatesAutoresizingMaskIntoConstraints = false
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    
    rightTopShimmerWidthConstraint = rightTopShimmerView.widthAnchor.constraint(equalToConstant: .shimmerWidth)
    rightBottomShimmerWidthConstraint = rightBottomShimmerView.widthAnchor.constraint(equalToConstant: .shimmerWidth)
    
    NSLayoutConstraint.activate([
      leftLabel.topAnchor.constraint(equalTo: topAnchor, constant: ContentInsets.sideSpace),
      leftLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      
      rightStackView.topAnchor.constraint(equalTo: topAnchor, constant: ContentInsets.sideSpace),
      rightStackView.leftAnchor.constraint(greaterThanOrEqualTo: leftLabel.rightAnchor, constant: .leftRightSpacing),
      rightStackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      rightStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -ContentInsets.sideSpace),
      
      rightTopShimmerView.heightAnchor.constraint(equalToConstant: .rightTopShimmerHeight),
      rightBottomShimmerView.heightAnchor.constraint(equalToConstant: .rightBottomShimmerheight),

      separatorView.leftAnchor.constraint(equalTo: leftLabel.leftAnchor),
      separatorView.rightAnchor.constraint(equalTo: rightAnchor),
      separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
      separatorView.heightAnchor.constraint(equalToConstant: 0.5)
    ])
  }
  
  func didUpdateIsHighlighted() {
    backgroundColor = isHighlighted ? .Background.highlighted : .Background.content
  }
}

private extension CGFloat {
  static let leftRightSpacing: CGFloat = 18
  static let rightTopShimmerHeight: CGFloat = 22
  static let rightBottomShimmerheight: CGFloat = 20
  static let shimmerWidth: CGFloat = 50
}

