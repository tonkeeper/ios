import UIKit

public final class TKQRCodeImageView: UIImageView {
  
  public var ips: TimeInterval = 0.1 {
    didSet {
      guard let animationImages else { return }
      animationDuration = ips * TimeInterval(animationImages.count)
    }
  }
  
  public func setQRCode(_ qrCode: QRCode?) {
    switch qrCode {
    case .none:
      image = nil
      animationImages = nil
      stopAnimating()
    case .static(let qrCodeImage):
      stopAnimating()
      animationImages = nil
      image = qrCodeImage
    case .dynamic(let qrCodeImages):
      image = nil
      stopAnimating()
      animationImages = fixImages(qrCodeImages)
      animationDuration = ips * TimeInterval(qrCodeImages.count)
      startAnimating()
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    contentMode = .center
  }
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func fixImages(_ images: [UIImage]) -> [UIImage] {
    let context = CIContext(options: nil)
    return images.compactMap { image -> UIImage? in
      guard image.cgImage == nil else { return image }
      guard let ciImage = image.ciImage else { return nil }
      guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
        return nil
      }
      return UIImage(cgImage: cgImage)
    }
  }
}
