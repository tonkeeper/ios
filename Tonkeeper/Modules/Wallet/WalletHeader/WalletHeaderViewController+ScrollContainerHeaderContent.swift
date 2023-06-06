//
//  WalletHeaderViewController+ScrollContainerHeaderContent.swift
//  Tonkeeper
//
//  Created by Grigory on 29.5.23..
//

import UIKit

extension WalletHeaderViewController: ScrollContainerHeaderContent {
  var height: CGFloat {
    view.systemLayoutSizeFitting(.zero).height
  }
  
  var minimumHeight: CGFloat {
    customView.titleView.systemLayoutSizeFitting(.zero).height
  }
  
  func update(with headerScrollProgress: CGFloat) {
    let alpha = 1 - headerScrollProgress
    customView.balanceLabel.alpha = alpha
    customView.addressButton.alpha = alpha
    customView.buttonsView.alpha = alpha
    
    let titleOffset = height - customView.titleView.systemLayoutSizeFitting(.zero).height
    let transform = CGAffineTransform(translationX: 0, y: titleOffset * headerScrollProgress)
    customView.titleView.transform = transform
  }
}
