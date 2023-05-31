//
//  TokensListTokensListView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 26/05/2023.
//

import UIKit

final class TokensListView: UIView {
  
  let collectionView = UICollectionView(frame: .zero, collectionViewLayout: .init())
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout
  
  override func layoutSubviews() {
    super.layoutSubviews()
    collectionView.frame = bounds
  }
}

// MARK: - Private

private extension TokensListView {
  func setup() {
    collectionView.backgroundColor = .Background.page
    
    addSubview(collectionView)
  }
}
