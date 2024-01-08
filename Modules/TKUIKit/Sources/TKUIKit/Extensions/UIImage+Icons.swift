//
//  UIImage+Icons.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

public extension UIImage {
  enum Icons {
    public enum Collectible {
      public static var sale: UIImage? {
          .imageWithName("Icons/16/ic-sale-badge-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum Transaction {
      public static var receieved: UIImage? {
        .imageWithName("Icons/28/ic-tray-arrow-down-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var sent: UIImage? {
        .imageWithName("Icons/28/ic-tray-arrow-up-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var spam: UIImage? {
        .imageWithName("Icons/28/ic-tray-arrow-down-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var bounced: UIImage? {
        .imageWithName("Icons/28/ic-return-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var subscribed: UIImage? {
        .imageWithName("Icons/28/ic-bell-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var unsubscribed: UIImage? {
        .imageWithName("Icons/28/ic-xmark-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var walletInitialized: UIImage? {
        .imageWithName("Icons/28/ic-donemark-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var nftCollectionCreation: UIImage? {
        .imageWithName("Icons/28/ic-gear-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var nftCreation: UIImage? {
        .imageWithName("Icons/28/ic-gear-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var smartContractExec: UIImage? {
        .imageWithName("Icons/28/ic-gear-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var removalFromSale: UIImage? {
        .imageWithName("Icons/28/ic-xmark-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var nftPurchase: UIImage? {
        .imageWithName("Icons/28/ic-shopping-bag-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var bid: UIImage? {
        .imageWithName("Icons/28/ic-tray-arrow-up-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var putUpForAuction: UIImage? {
        .imageWithName("Icons/28/ic-tray-arrow-up-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var endOfAuction: UIImage? {
        .imageWithName("Icons/28/ic-xmark-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var putUpForSale: UIImage? {
        .imageWithName("Icons/28/ic-sale-badge-28")?.withRenderingMode(.alwaysTemplate)
      }
        
      public static var swap: UIImage? {
        .imageWithName("Icons/28/ic-swap-horizontal-alternative-28")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum Service {
      public static var chevron: UIImage? {
        .imageWithName("Icons/16/ic-chevron-right-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum TextField {
      public static var clear: UIImage? {
        .imageWithName("Icons/16/ic-xmark-circle-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum State {
      public static var success: UIImage? {
        .imageWithName("Icons/32/ic-checkmark-circle-32")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var fail: UIImage? {
        .imageWithName("Icons/32/ic-exclamationmark-circle-32")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum Buttons {
      public static var scanQR: UIImage? {
        .imageWithName("Icons/28/ic-qr-viewfinder-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var flashlight: UIImage? {
        .imageWithName("Icons/56/ic-flashlight-off-56")?.withRenderingMode(.alwaysTemplate)
      }
      
      public enum Receive {
        public static var copy: UIImage? {
          .imageWithName("Icons/16/ic-copy-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var share: UIImage? {
          .imageWithName("Icons/16/ic-share-16")?.withRenderingMode(.alwaysTemplate)
        }
      }
      
      public enum Wallet {
        public static var buy: UIImage? {
          .imageWithName("Icons/28/ic-plus-28")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var send: UIImage? {
          .imageWithName("Icons/28/ic-arrow-up-28")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var recieve: UIImage? {
          .imageWithName("Icons/28/ic-arrow-down-28")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var sell: UIImage? {
          .imageWithName("Icons/28/ic-minus-28")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var swap: UIImage? {
          .imageWithName("Icons/28/ic-swap-horizontal-28")?.withRenderingMode(.alwaysTemplate)
        }
      }
      
      public enum Header {
        public static var swipe: UIImage? {
          .imageWithName("Icons/16/ic-chevron-down-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var close: UIImage? {
          .imageWithName("Icons/16/ic-close-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var back: UIImage? {
          .imageWithName("Icons/16/ic-chevron-left-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var more: UIImage? {
          .imageWithName("Icons/16/ic-ellipsis-16")?.withRenderingMode(.alwaysTemplate)
        }
      }
      
      public enum TonDetailsLinks {
        public static var tonOrg: UIImage? {
          .imageWithName("Icons/16/ic-globe-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var twitter: UIImage? {
          .imageWithName("Icons/16/ic-twitter-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var chat: UIImage? {
          .imageWithName("Icons/16/ic-telegram-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var community: UIImage? {
          .imageWithName("Icons/16/ic-telegram-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var whitepaper: UIImage? {
          .imageWithName("Icons/16/ic-doc-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var tonviewer: UIImage? {
          .imageWithName("Icons/16/ic-magnifying-glass-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var sourceCode: UIImage? {
          .imageWithName("Icons/16/ic-code-16")?.withRenderingMode(.alwaysTemplate)
        }
      }
    }
    
    public enum TabBar {
      public static var wallet: UIImage? {
        .imageWithName("Icons/28/ic-wallet-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var activity: UIImage? {
        .imageWithName("Icons/28/ic-flash-28")?.withRenderingMode(.alwaysTemplate)
      }
                                                               
      public static var browser: UIImage? {
        .imageWithName("Icons/28/ic-explore-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var settings: UIImage? {
        .imageWithName("Icons/28/ic-gear-28")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum Welcome {
      public static var speed: UIImage? {
        .imageWithName("Icons/28/ic-rocket-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var security: UIImage? {
        .imageWithName("Icons/28/ic-shield-28")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum PasscodeButton {
      public static var faceId: UIImage? {
        .imageWithName("Icons/36/ic-faceid-36")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var touchId: UIImage? {
        .imageWithName("Icons/36/ic-fingerprint-36")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var backspace: UIImage? {
        .imageWithName("Icons/36/ic-delete-36")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum TKMenu {
      public static var tick: UIImage? {
        .imageWithName("Icons/16/ic-done-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum InAppBrowser {
      public static var ssl: UIImage? {
        .imageWithName("Icons/12/ic-lock-12")?.withRenderingMode(.alwaysTemplate)
      }
      
      public enum Menu {
        public static var share: UIImage? {
          .imageWithName("Icons/16/ic-share-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var copy: UIImage? {
          .imageWithName("Icons/16/ic-copy-16")?.withRenderingMode(.alwaysTemplate)
        }
        
        public static var refresh: UIImage? {
          .imageWithName("Icons/16/ic-refresh-16")?.withRenderingMode(.alwaysTemplate)
        }
      }
    }
      
    public enum SettingsList {
      public static var logout: UIImage? {
        .imageWithName("Icons/28/ic-door-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var delete: UIImage? {
        .imageWithName("Icons/28/ic-trash-bin-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var security: UIImage? {
        .imageWithName("Icons/28/ic-key-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public  static var changePasscode: UIImage? {
        .imageWithName("Icons/28/ic-lock-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var chevron: UIImage? {
        .imageWithName("Icons/16/ic-chevron-right-16")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var checkmark: UIImage? {
        .imageWithName("Icons/28/ic-donemark-thin-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var recoveryPhrase: UIImage? {
        .imageWithName("Icons/28/ic-key-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var support: UIImage? {
        .imageWithName("Icons/28/ic-telegram-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var tonkeeperNews: UIImage? {
        .imageWithName("Icons/28/ic-telegram-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var contactUs: UIImage? {
        .imageWithName("Icons/28/ic-message-bubble-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var legal: UIImage? {
        .imageWithName("Icons/28/ic-doc-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      public static var rate: UIImage? {
        .imageWithName("Icons/28/ic-star-28")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum Controls {
      public static var checkmark: UIImage? {
        .imageWithName("Icons/16/ic-done-bold-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum Permission {
      public static var camera: UIImage? {
        .imageWithName("Icons/84/ic-camera-84")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public enum Mock {
      public static var tonCurrencyIcon: UIImage? {
        .imageWithName("Icons/44/ton_currency_icon")
      }
    }
    
    public enum Size16 {
      public static var globe16: UIImage? {
        .imageWithName("Icons/16/ic-globe-16")?.withRenderingMode(.alwaysTemplate)
      }
    }
    
    public static var tonIcon28: UIImage? {
      .imageWithName("Icons/28/ic-ton-28")?.withRenderingMode(.alwaysTemplate)
    }
    
    public static var tonIcon128: UIImage? {
      .imageWithName("Icons/128/ic-logo-128")?.withRenderingMode(.alwaysTemplate)
    }
    
    public static var tonIcon: UIImage? {
      .imageWithName("Icons/44/ton_currency_icon")
    }
  }
}



