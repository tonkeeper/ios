import CoreGraphics
@testable import TKUIKit

enum QRCodeViewTestConstants {
    static let addressPayload = "UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJKZ"
    static let transferPayload = "tonkeeper://transfer/UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJKZ"
    static let centerCutoutSize = CGSize(width: 60, height: 60)
    static let renderSize = CGSize(width: 320, height: 320)

    /// Largest cutout used in production (the Receive screen, see `ReceiveViewModel`).
    static let productionCenterCutoutSize = CGSize(width: 72, height: 72)
    /// Render size close to the actual Receive QR card so the cutout-to-size
    /// ratio (and therefore the share of erased modules) matches production.
    static let compactRenderSize = CGSize(width: 280, height: 280)
    /// A dense payload that pushes the QR to a high version (small modules),
    /// the worst case for dotted rendering combined with a center cutout.
    static let densePayload = densePayload(length: 220)

    static func densePayload(length: Int) -> String {
        let seed = "tonkeeper://transfer/UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJKZ?text="
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let repeated = String(repeating: alphabet, count: max(1, length / alphabet.count + 1))
        return seed + String(repeated.prefix(length))
    }

    static let rippleBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    static let rippleOrigin = CGPoint(x: 0, y: 0)
    static let rippleModuleSide: CGFloat = 10
    static let rippleRingMidpoint = CGPoint(x: 50, y: 50)
    static let rippleConfiguration = QrCodeRippleConfiguration(ringWidthInModules: 2)
    static let slowRippleConfiguration = QrCodeRippleConfiguration(
        animationDuration: 2,
        ringWidthInModules: 2
    )

    static let activeTapOrigin = CGPoint(x: 25, y: 25)
    static let tapModuleSide: CGFloat = 10
    static let tapRippleConfiguration = QrCodeRippleConfiguration(ringWidthInModules: 2)
    static let expandedTapRippleConfiguration = QrCodeRippleConfiguration(
        ringWidthInModules: 2,
        activeTapRadiusInModules: 4
    )
    static var tapRadius: CGFloat {
        tapRippleConfiguration.activeTapRadiusInModules * tapModuleSide
    }

    static var expandedTapRadius: CGFloat {
        expandedTapRippleConfiguration.activeTapRadiusInModules * tapModuleSide
    }

    static let influenceAccuracy: CGFloat = 0.0001
}
