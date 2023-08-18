//
//  TonDetailsLinks.swift
//  Tonkeeper
//
//  Created by Grigory on 18.8.23..
//

import Foundation

struct TonDetailsLinks {
  static var tonURL: TKURL {
    .inApp(URL(string: "https://ton.org")!)
  }
  
  static var twitterURL: TKURL {
    .system(URL(string: "https://twitter.com/ton_blockchain")!)
  }
  
  static var chatURL: TKURL {
    .system(URL(string: "https://t.me/toncoin_chat")!)
  }
  
  static var communityURL: TKURL {
    .system(URL(string: "https://t.me/toncoin")!)
  }
  
  static var whitepaperURL: TKURL {
    .system(URL(string: "https://ton.org/whitepaper.pdf")!)
  }
  
  static var tonviewerURL: TKURL {
    .inApp(URL(string: "https://tonviewer.com/")!)
  }
  
  static var sourceCodeURL: TKURL {
    .system(URL(string: "https://github.com/ton-blockchain/ton")!)
  }
}
