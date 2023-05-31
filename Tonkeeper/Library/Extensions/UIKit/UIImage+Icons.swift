//
//  UIImage+Icons.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

extension UIImage {
  enum Icons {
    enum Collectible {
      static var sale: UIImage? {
        .init(named: "Icons/16/ic-sale-badge-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    enum Buttons {
      static var scanQR: UIImage? {
        .init(named: "Icons/28/ic-qr-viewfinder-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var flashlight: UIImage? {
        .init(named: "Icons/56/ic-flashlight-off-56")?.withRenderingMode(.alwaysTemplate)
      }
      
      enum Wallet {
        static var buy: UIImage? {
          .init(named: "Icons/28/ic-plus-28")?.withRenderingMode(.alwaysTemplate)
        }
        
        static var send: UIImage? {
          .init(named: "Icons/28/ic-arrow-up-28")?.withRenderingMode(.alwaysTemplate)
        }
        
        static var recieve: UIImage? {
          .init(named: "Icons/28/ic-arrow-down-28")?.withRenderingMode(.alwaysTemplate)
        }
        
        static var sell: UIImage? {
          .init(named: "Icons/28/ic-minus-28")?.withRenderingMode(.alwaysTemplate)
        }
        
        static var swap: UIImage? {
          .init(named: "Icons/28/ic-swap-horizontal-28")?.withRenderingMode(.alwaysTemplate)
        }
      }
      
      enum Header {
        static var swipe: UIImage? {
          .init(named: "Icons/16/ic-chevron-down-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        static var close: UIImage? {
          .init(named: "Icons/16/ic-close-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        static var back: UIImage? {
          .init(named: "Icons/16/ic-chevron-left-16")?.withRenderingMode(.alwaysTemplate)
        }
      }
    }
    
    enum TabBar {
      static var wallet: UIImage? {
        .init(named: "Icons/28/ic-wallet-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var activity: UIImage? {
        .init(named: "Icons/28/ic-flash-28")?.withRenderingMode(.alwaysTemplate)
      }
                                                               
      static var browser: UIImage? {
        .init(named: "Icons/28/ic-explore-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var settings: UIImage? {
        .init(named: "Icons/28/ic-gear-28")?.withRenderingMode(.alwaysTemplate)
      }
    }
  }
}
