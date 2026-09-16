import UIKit

public struct QrCodeGeneratorConfiguration: Sendable, Equatable {
    public var centerCutoutSize: CGSize?
    public var errorCorrectionLevel: QrCodeErrorCorrectionLevel
    public var quietZoneInModules: Int
    public var dotDiameterRatio: CGFloat
    public var backgroundColor: UIColor

    public init(
        centerCutoutSize: CGSize? = nil,
        errorCorrectionLevel: QrCodeErrorCorrectionLevel? = nil,
        quietZoneInModules: Int? = nil,
        dotDiameterRatio: CGFloat? = nil,
        backgroundColor: UIColor? = nil
    ) {
        self.centerCutoutSize = centerCutoutSize
        self.errorCorrectionLevel = errorCorrectionLevel ?? Constants.errorCorrectionLevel
        self.quietZoneInModules = max(
            quietZoneInModules ?? Constants.quietZoneInModules,
            Constants.minQuietZoneInModules
        )
        self.dotDiameterRatio = max(
            dotDiameterRatio ?? Constants.dotDiameterRatio,
            Constants.minDotDiameterRatio
        )
        self.backgroundColor = backgroundColor ?? Constants.backgroundColor
    }
}

public extension QrCodeGeneratorConfiguration {
    static var `default`: Self {
        QrCodeGeneratorConfiguration()
    }

    var resolvedErrorCorrectionLevel: QrCodeErrorCorrectionLevel {
        switch errorCorrectionLevel {
        case .automatic:
            centerCutoutSize == nil ? .medium : .high
        case .low, .medium, .quartile, .high:
            errorCorrectionLevel
        }
    }
}

extension QrCodeGeneratorConfiguration {
    enum Constants {
        static let errorCorrectionLevel: QrCodeErrorCorrectionLevel = .automatic

        static let minQuietZoneInModules = 0
        static let quietZoneInModules = 3

        static let minDotDiameterRatio: CGFloat = 0
        static let dotDiameterRatio: CGFloat = 0.8

        static let backgroundColor: UIColor = .white
    }
}
