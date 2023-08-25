//
//  CollectibleDetailsCollectionDescriptionView.swift
//  Tonkeeper
//
//  Created by Grigory on 22.8.23..
//

import UIKit

final class CollectibleDetailsCollectionDescriptionView: UIView, ConfigurableView {
  
  let titleLabel = UILabel()
  
  let descriptionView: MoreTextViewContainer = {
    let view = MoreTextViewContainer()
    view.numberOfLinesInCollapsed = 3
    return view
  }()
  
  private let contentView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: String?
    let description: String?
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title?.attributed(
      with: .label1,
      alignment: .left,
      lineBreakMode: .byWordWrapping,
      color: .Text.primary)
    
    descriptionView.attributedText = model.description?.attributed(
      with: .body2,
      alignment: .left,
      lineBreakMode: .byWordWrapping,
      color: .Text.secondary)
  }
}

private extension CollectibleDetailsCollectionDescriptionView {
  func setup() {
    addSubview(contentView)
    contentView.addSubview(titleLabel)
    contentView.addSubview(descriptionView)
    
    contentView.backgroundColor = .Background.content
    contentView.layer.cornerRadius = 16
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    descriptionView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: topAnchor),
      contentView.leftAnchor.constraint(equalTo: leftAnchor),
      contentView.rightAnchor.constraint(equalTo: rightAnchor),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: ContentInsets.sideSpace),
      titleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: ContentInsets.sideSpace),
      titleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -ContentInsets.sideSpace),
      
      descriptionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: .descriptionTopSpace),
      descriptionView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: ContentInsets.sideSpace),
      descriptionView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -ContentInsets.sideSpace),
      descriptionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -ContentInsets.sideSpace)
    ])
  }
}

private extension CGFloat {
  static let descriptionTopSpace: CGFloat = 8
}
