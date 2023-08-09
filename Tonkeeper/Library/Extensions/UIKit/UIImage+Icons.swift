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
    
    enum Transaction {
      static var receieved: UIImage? {
        .init(named: "Icons/28/ic-tray-arrow-down-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var sent: UIImage? {
        .init(named: "Icons/28/ic-tray-arrow-up-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var spam: UIImage? {
        .init(named: "Icons/28/ic-tray-arrow-down-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var bounced: UIImage? {
        .init(named: "Icons/28/ic-return-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var subscribed: UIImage? {
        .init(named: "Icons/28/ic-bell-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var unsubscribed: UIImage? {
        .init(named: "Icons/28/ic-xmark-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var walletInitialized: UIImage? {
        .init(named: "Icons/28/ic-donemark-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var nftCollectionCreation: UIImage? {
        .init(named: "Icons/28/ic-gear-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var nftCreation: UIImage? {
        .init(named: "Icons/28/ic-gear-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var smartContractExec: UIImage? {
        .init(named: "Icons/28/ic-gear-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var removalFromSale: UIImage? {
        .init(named: "Icons/28/ic-xmark-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var nftPurchase: UIImage? {
        .init(named: "Icons/28/ic-shopping-bag-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var bid: UIImage? {
        .init(named: "Icons/28/ic-tray-arrow-up-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var putUpForAuction: UIImage? {
        .init(named: "Icons/28/ic-tray-arrow-up-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var endOfAuction: UIImage? {
        .init(named: "Icons/28/ic-xmark-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var putUpForSale: UIImage? {
        .init(named: "Icons/28/ic-sale-badge-28")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    enum Service {
      static var chevron: UIImage? {
        .init(named: "Icons/16/ic-chevron-right-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    enum TextField {
      static var clear: UIImage? {
        .init(named: "Icons/16/ic-xmark-circle-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    enum State {
      static var success: UIImage? {
        .init(named: "Icons/32/ic-checkmark-circle-32")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var fail: UIImage? {
        .init(named: "Icons/32/ic-exclamationmark-circle-32")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    enum Buttons {
      static var scanQR: UIImage? {
        .init(named: "Icons/28/ic-qr-viewfinder-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var flashlight: UIImage? {
        .init(named: "Icons/56/ic-flashlight-off-56")?.withRenderingMode(.alwaysTemplate)
      }
      
      enum Receive {
        static var copy: UIImage? {
          .init(named: "Icons/16/ic-copy-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        static var share: UIImage? {
          .init(named: "Icons/16/ic-share-16")?.withRenderingMode(.alwaysTemplate)
        }
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
    
    enum Welcome {
      static var speed: UIImage? {
        .init(named: "Icons/28/ic-rocket-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var security: UIImage? {
        .init(named: "Icons/28/ic-shield-28")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    enum PasscodeButton {
      static var biometry: UIImage? {
        .init(named: "Icons/36/ic-faceid-36")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var backspace: UIImage? {
        .init(named: "Icons/36/ic-delete-36")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    enum TKMenu {
      static var tick: UIImage? {
        .init(named: "Icons/16/ic-done-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    enum Mock {
      static var tonCurrencyIcon: UIImage? {
        .init(named: "Icons/44/ton_currency_icon")
      }
    }
    
    static var tonIcon28: UIImage? {
      .init(named: "Icons/28/ic-ton-28")?.withRenderingMode(.alwaysTemplate)
    }
    
    static var tonIcon128: UIImage? {
      .init(named: "Icons/128/ic-logo-128")?.withRenderingMode(.alwaysTemplate)
    }
    
    static var tonIcon: UIImage? {
      .init(named: "Icons/44/ic-ton-44")?.withRenderingMode(.alwaysTemplate)
    }
  }
}
