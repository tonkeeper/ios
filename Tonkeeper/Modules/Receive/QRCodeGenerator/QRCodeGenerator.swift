//
//  QRCodeGenerator.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import UIKit

protocol QRCodeGenerator {
  func generate(string: String, size: CGSize) async -> UIImage?
}

struct DefaultQRCodeGenerator: QRCodeGenerator {
  func generate(string: String, size: CGSize) async -> UIImage? {
    let data = string.data(using: .ascii)
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    guard let qrCodeImage = filter.outputImage else { return nil }
    let scaleX = size.width / qrCodeImage.extent.size.width
    let scaleY = size.height / qrCodeImage.extent.size.height
    let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
    let scaledImage = qrCodeImage.transformed(by: transform)
    
    return UIImage(ciImage: scaledImage)
  }
}
