//
//  SettingsListCellContentView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit
import TKUIKit

final class SettingsListCellContentView: UIView, ContainerCollectionViewCellContent {
  
  let titleLabel = UILabel()
  private let contentContainer = UIStackView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: String
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.attributed(
      with: .label1,
      alignment: .left,
      color: .Text.primary
    )
  }
  
  func prepareForReuse() {
    titleLabel.attributedText = nil
  }
}

private extension SettingsListCellContentView {
  func setup() {
    addSubview(contentContainer)
    
    contentContainer.addArrangedSubview(titleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      contentContainer.topAnchor.constraint(equalTo: topAnchor, constant: ContentInsets.sideSpace),
      contentContainer.leftAnchor.constraint(equalTo: leftAnchor, constant: ContentInsets.sideSpace),
      contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -ContentInsets.sideSpace),
      contentContainer.rightAnchor.constraint(equalTo: rightAnchor, constant: -ContentInsets.sideSpace)
    ])
  }
}
