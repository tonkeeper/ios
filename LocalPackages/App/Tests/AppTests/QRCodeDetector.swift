import CoreImage
import UIKit

enum QRCodeDetector {
    static func detectPayload(in image: UIImage) -> String? {
        guard let image = image.compositedOnWhiteBackground(),
              let cgImage = image.cgImage
        else {
            return nil
        }

        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: CIImage(cgImage: cgImage)) as? [CIQRCodeFeature]
        return features?.first?.messageString
    }
}
