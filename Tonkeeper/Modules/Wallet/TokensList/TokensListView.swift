//
//  TokensListTokensListView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 26/05/2023.
//

import UIKit

final class TokensListView: UIView {
  
  lazy var collectionView: UICollectionView = {
    let layout = collectionLayoutConfigurator.getLayout { [weak self] sectionIndex in
      guard let self = self else { return .token }
      return .token
    }
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    return collectionView
  }()
  
  private let collectionLayoutConfigurator = TokensListCollectionLayoutConfigurator()

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
