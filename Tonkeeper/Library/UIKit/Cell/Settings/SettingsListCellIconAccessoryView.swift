//
//  SettingsListCellIconAccessoryView.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit
import TKUIKitLegacy

final class SettingsListCellIconAccessoryView: UIView {
  
  let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .center
    return imageView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let image: UIImage?
    let tintColor: UIColor
  }
  
  func configure(model: Model) {
    imageView.image = model.image
    imageView.tintColor = model.tintColor
  }
  
  override var intrinsicContentSize: CGSize {
    .init(width: .imageSide, height: .imageSide)
  }
}

private extension SettingsListCellIconAccessoryView {
  func setup() {
    addSubview(imageView)
    setupConstraints()
  }
  
  func setupConstraints() {
    imageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
      imageView.widthAnchor.constraint(equalToConstant: .imageSide),
      imageView.heightAnchor.constraint(equalToConstant: .imageSide),
      imageView.rightAnchor.constraint(equalTo: rightAnchor),
    ])
  }
}

private extension CGFloat {
  static let imageSide: CGFloat = 28
}



