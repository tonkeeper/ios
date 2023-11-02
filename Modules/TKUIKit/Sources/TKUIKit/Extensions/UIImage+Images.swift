//
//  UIImage+Images.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit

public extension UIImage {
  enum Images {
    
    public enum TonConnect {
      public static var tonkeeperLogo: UIImage? {
        .imageWithName("Images/tonkeeper_logo")
      }
    }
    
    public enum Mock {
      public static var nftImage: UIImage? {
        .imageWithName("Images/nft_image")
      }
      
      public static var mercuryoLogo: UIImage? {
        .imageWithName("Images/mercuryo_logo")
      }
    }
  }
}

