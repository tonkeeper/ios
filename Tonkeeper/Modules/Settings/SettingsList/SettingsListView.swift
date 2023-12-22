//
//  SettingsListSettingsListView.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import UIKit

final class SettingsListView: UIView {
  
  let collectionView = NotDelayCollectionView(frame: .zero, collectionViewLayout: .init())

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

private extension SettingsListView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    addSubview(collectionView)
    
    collectionView.contentInset.top = 11
  }
}
