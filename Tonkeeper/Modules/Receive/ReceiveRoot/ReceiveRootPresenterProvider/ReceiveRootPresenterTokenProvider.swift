//
//  ReceiveRootPresenterTokenProvider.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation
import WalletCore

struct ReceiveRootPresenterTokenProvider: ReceiveRootPresenterProvider {

  var title: String {
    "Receive \(tokenInfo.symbol ?? "")"
  }
  
  var image: Image {
    .url(tokenInfo.imageURL)
  }
  
  private let tokenInfo: TokenInfo
  
  init(tokenInfo: TokenInfo) {
    self.tokenInfo = tokenInfo
  }
}
