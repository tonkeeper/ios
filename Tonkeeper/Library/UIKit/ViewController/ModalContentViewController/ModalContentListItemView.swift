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
  
  let leftLabel = UILabel()
  
  let rightTopLabel = UILabel()
  
  let rightBottomLabel = UILabel()
  
  let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    return view
  }()
  
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
    rightTopLabel.attributedText = model.rightTop
      .attributed(with: .label1, alignment: .right, color: .Text.primary)
    rightBottomLabel.attributedText = model.rightBottom?
      .attributed(with: .body2, alignment: .right, color: .Text.secondary)
  }
}

private extension ModalContentListItemView {
  func setup() {
    didUpdateIsHighlighted()
    
    addSubview(leftLabel)
    addSubview(rightTopLabel)
    addSubview(rightBottomLabel)
    addSubview(separatorView)
    
    leftLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    leftLabel.translatesAutoresizingMaskIntoConstraints = false
    rightTopLabel.translatesAutoresizingMaskIntoConstraints = false
    rightBottomLabel.translatesAutoresizingMaskIntoConstraints = false
    separatorView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      leftLabel.topAnchor.constraint(equalTo: topAnchor, constant: ContentInsets.sideSpace),
      leftLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      
      rightTopLabel.topAnchor.constraint(equalTo: topAnchor, constant: ContentInsets.sideSpace),
      rightTopLabel.leftAnchor.constraint(equalTo: leftLabel.rightAnchor, constant: .leftRightSpacing),
      rightTopLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      
      rightBottomLabel.topAnchor.constraint(equalTo: rightTopLabel.bottomAnchor),
      rightBottomLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace),
      rightBottomLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -ContentInsets.sideSpace),
      
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
  static let leftRightSpacing: CGFloat = 20
}

