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
}
