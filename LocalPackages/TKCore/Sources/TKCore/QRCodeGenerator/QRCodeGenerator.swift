import UIKit

public protocol QRCodeGenerator {
  func generate(string: String, size: CGSize) async -> UIImage?
}

public struct QRCodeGeneratorImplementation: QRCodeGenerator {
  
  public init() {}
  
  public func generate(string: String, size: CGSize) async -> UIImage? {
    let data = string.data(using: .ascii)
    let filter = CIFilter(name: "CIQRCodeGenerator")
    filter?.setValue(data, forKey: "inputMessage")
    filter?.setValue("M", forKey: "inputCorrectionLevel")
    
    guard let qrCode = filter?.outputImage else { return nil }
    
    let scaleX = size.width / qrCode.extent.size.width
    let scaleY = size.height / qrCode.extent.size.height
    let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
    let scaledQRCode = qrCode.transformed(by: transform)
    
    return UIImage(ciImage: scaledQRCode)
  }
  
}
