//
//  SuccessViewController+Configuration.swift
//  Tonkeeper
//
//  Created by Grigory on 30.6.23..
//

import Foundation

extension SuccessViewController.Configuration {
  static var walletCreation: SuccessViewController.Configuration {
    let title = "Your wallet has just\nbeen created!"
      .attributed(with: .h2, alignment: .center, color: .Text.primary)
    return .init(title: title)
  }
  
  static var walletImport: SuccessViewController.Configuration {
    let title = "Congratulations! You've\nset up your wallet!"
      .attributed(with: .h2, alignment: .center, color: .Text.primary)
    return .init(title: title)
  }
}
