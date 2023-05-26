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
  }
  
  func configure(model: Model) {}
}
