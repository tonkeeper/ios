//
//  ReceiveRootPresenterAnyProvider.swift
//  Tonkeeper
//
//  Created by Grigory on 18.7.23..
//

import Foundation

struct ReceiveRootPresenterAnyProvider: ReceiveRootPresenterProvider {
  var title: String {
    "Receive TON\nand other tokens"
  }
  
  var image: Image {
    .image(.Icons.tonIcon, tinColor: .Icon.primary, backgroundColor: .Constant.tonBlue)
  }
}
