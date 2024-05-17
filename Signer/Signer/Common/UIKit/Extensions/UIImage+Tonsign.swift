//
//  UIImage+Tonsign.swift
//  Signer
//
//  Created by Grigory Serebryanyy on 07.12.2023.
//

import UIKit

extension UIImage {
  enum Images {
    public static var tonsignCover: UIImage? {
      .imageWithName("Images/tonsign_cover")
    }
  }
}

extension UIImage {
    static func imageWithName(_ name: String) -> UIImage? {
      return UIImage(named: name, in: .main, with: nil)
    }
}
