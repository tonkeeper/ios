import UIKit.UIImage

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
