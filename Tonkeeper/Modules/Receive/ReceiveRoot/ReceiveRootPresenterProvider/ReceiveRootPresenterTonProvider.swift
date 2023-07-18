//
//  ReceiveRootPresenterTonProvider.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation

struct ReceiveRootPresenterTonProvider: ReceiveRootPresenterProvider {
  var title: String {
    "Receive TON"
  }
  
  var image: Image {
    .image(.Icons.tonIcon, tinColor: .Icon.primary, backgroundColor: .Constant.tonBlue)
  }
}
