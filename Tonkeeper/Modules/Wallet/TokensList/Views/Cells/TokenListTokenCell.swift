//
//  TokenListTokenCell.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import UIKit

final class TokenListTokenCell: UICollectionViewCell, Reusable, ConfigurableView {
  struct Model {
    static var cellType: Reusable.Type = TokenListTokenCell.self
  }
  
  func configure(model: Model) {}
}
