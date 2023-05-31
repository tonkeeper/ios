//
//  WalletHeaderViewController+ScrollContainerHeaderContent.swift
//  Tonkeeper
//
//  Created by Grigory on 29.5.23..
//

import UIKit

extension WalletHeaderViewController: ScrollContainerHeaderContent {
  var height: CGFloat {
    round(view.systemLayoutSizeFitting(.zero).height)
  }
  
  func update(with headerScrollProgress: CGFloat) {
    view.alpha = 1 - headerScrollProgress
//    amountTitle.alpha = 1 - headerScrollProgress
//    amountSubtitle.alpha = 1 - headerScrollProgress
//    buttonsView.alpha = 1 - headerScrollProgress
  }
}
