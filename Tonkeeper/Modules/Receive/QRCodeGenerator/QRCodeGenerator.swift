//
//  QRCodeGenerator.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

protocol QRCodeGenerator {
  func generate(string: String) -> UIImage?
}

struct DefaultQRCodeGenerator: QRCodeGenerator {
  func generate(string: String) -> UIImage? {
    let data = string.data(using: .ascii)
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    guard let qrCodeImage = filter.outputImage else { return nil }
    return UIImage(ciImage: qrCodeImage)
  }
}
