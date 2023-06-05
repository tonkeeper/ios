//
//  WalletHeaderButtonType.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import UIKit

struct WalletHeaderButtonModel {
  enum ButtonType {
    case buy
    case send
    case receive
    case sell
    case swap
    
    var title: String {
      switch self {
      case .buy: return "Buy TON"
      case .receive: return "Receive"
      case .sell: return "Sell"
      case .send: return "Send"
      case .swap: return "Swap"
      }
    }
    
    var icon: UIImage? {
      switch self {
      case .buy: return .Icons.Buttons.Wallet.buy
      case .receive: return .Icons.Buttons.Wallet.recieve
      case .sell: return .Icons.Buttons.Wallet.sell
      case .send: return .Icons.Buttons.Wallet.send
      case .swap: return .Icons.Buttons.Wallet.swap
      }
    }
  }
  
  let viewModel: IconButton.Model
  let handler: (() -> Void)?
}

