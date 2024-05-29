import Foundation
import UIKit.UIImage

public enum QRCode: Hashable {
  case `static`(UIImage)
  case dynamic([UIImage])
  
  public var images: [UIImage] {
    switch self {
    case .static(let qrCodeImage):
      return [qrCodeImage]
    case .dynamic(let qrCodeImages):
      return qrCodeImages
    }
  }
}

public enum QRCodeType {
  case `static`
  case dynamic(charLimit: Int)
}

public enum QRCodeGeneratorError: Swift.Error {
  case failedGenerateQRCode
  case failedGenerateDynamicQRCode
}

public protocol TKQRCodeGenerator {
  func generateQRCode(string: String, size: CGSize, type: QRCodeType) async throws -> QRCode
}

struct TKQRCodeGeneratorImplementation: TKQRCodeGenerator {
  func generateQRCode(string: String, size: CGSize, type: QRCodeType) async throws -> QRCode {
    switch type {
    case .static:
      return try await .static(
        generateStaticQRCode(
          string: string,
          size: size
        )
      )
    case .dynamic(let charLimit):
      return try await .dynamic(
        generateDynamicQRCode(
          string: string,
          size: size,
          charLimit: charLimit
        )
      )
    }
  }
}

private extension TKQRCodeGeneratorImplementation {
  func generateStaticQRCode(string: String, size: CGSize) async throws -> UIImage {
    guard let qrCodeImage = await generateQRCode(string: string, size: size) else {
      throw QRCodeGeneratorError.failedGenerateQRCode
    }
    return qrCodeImage
  }
  
  func generateDynamicQRCode(string: String, size: CGSize, charLimit: Int) async throws -> [UIImage] {
    let chunks = string.split(by: 256)
    var qrCodeImages = [UIImage]()
    for chunk in chunks {
      try Task.checkCancellation()
      guard let qrCodeImage = await generateQRCode(string: chunk, size: size) else {
        throw QRCodeGeneratorError.failedGenerateDynamicQRCode
      }
      qrCodeImages.append(qrCodeImage)
    }
    return qrCodeImages
  }
  
  func generateQRCode(string: String, size: CGSize) async -> UIImage? {
    let data = string.data(using: .ascii)
    let filter = CIFilter(name: "CIQRCodeGenerator")
    filter?.setValue(data, forKey: "inputMessage")
    filter?.setValue("M", forKey: "inputCorrectionLevel")

    let colorFilter = CIFilter(name: "CIFalseColor")
    colorFilter?.setDefaults()
    colorFilter?.setValue(filter?.outputImage, forKey: "inputImage")

    let transparentBG: CIColor = CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    colorFilter?.setValue(CIColor(cgColor: UIColor.black.cgColor), forKey: "inputColor0")
    colorFilter?.setValue(transparentBG, forKey: "inputColor1")
    guard let outputImage = colorFilter?.outputImage else { return nil }

    let scaleX = size.width / outputImage.extent.size.width
    let scaleY = size.height / outputImage.extent.size.height
    let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
    let scaledQRCode = outputImage.transformed(by: transform)
    return UIImage(ciImage: scaledQRCode)
  }
}

private extension String {
  func split(by length: Int) -> [String] {
    var startIndex = self.startIndex
    var results = [Substring]()
    
    while startIndex < self.endIndex {
      let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
      results.append(self[startIndex..<endIndex])
      startIndex = endIndex
    }
    
    return results.map { String($0) }
  }
}
