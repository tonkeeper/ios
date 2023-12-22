//
//  NotDelayCollectionView.swift
//  Tonkeeper
//
//  Created by Grigory on 6.8.23..
//

import UIKit

final class NotDelayCollectionView: UICollectionView {
  override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
    super.init(frame: frame, collectionViewLayout: layout)
    self.delaysContentTouches = false
    self.canCancelContentTouches = true
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func touchesShouldCancel(in view: UIView) -> Bool {
    guard !(view is UIControl) else { return true }
    return super.touchesShouldCancel(in: view)
  }
}

