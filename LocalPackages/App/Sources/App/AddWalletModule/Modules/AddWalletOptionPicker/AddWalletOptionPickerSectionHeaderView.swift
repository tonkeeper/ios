//
//  AddWalletOptionPickerSectionHeaderView.swift
//  App
//
//  Created by Andrei Ponomarenko on 25.06.2025.
//

import UIKit

final class AddWalletOptionPickerSectionHeaderView: UICollectionReusableView {
  let titleLabel = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(titleLabel)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
      titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
      titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
      titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
    ])
    titleLabel.numberOfLines = 0
    titleLabel.setContentHuggingPriority(.required, for: .vertical)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
