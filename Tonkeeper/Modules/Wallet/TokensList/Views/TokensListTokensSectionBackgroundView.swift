//
//  TokensListTokensSectionBackgroundView.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import UIKit

final class TokensListTokensSectionBackgroundView: UICollectionReusableView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    layer.cornerRadius = .cornerRadius
    backgroundColor = .Background.content
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
}
