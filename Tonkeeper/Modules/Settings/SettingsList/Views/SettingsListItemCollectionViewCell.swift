//
//  SettingsListItemCollectionViewCell.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit

final class SettingsListItemCollectionViewCell: ContainerCollectionViewCell<SettingsListCellContentView>, Reusable {
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
