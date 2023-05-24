//
//  UIImage+Icons.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

extension UIImage {
  enum Icons {
    enum Buttons {
      static var scanQR: UIImage? {
        .init(named: "Icons/28/ic-qr-viewfinder-28")?.withRenderingMode(.alwaysTemplate)
      }
      
      static var flashlight: UIImage? {
        .init(named: "Icons/56/ic-flashlight-off-56")?.withRenderingMode(.alwaysTemplate)
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
