import UIKit

enum QrCodeTapEffect {
    static let maximumInfluence: CGFloat = 1

    static func influence(
        at point: CGPoint,
        activeTapOrigin: CGPoint?,
        moduleSide: CGFloat,
        rippleConfiguration: QrCodeRippleConfiguration
    ) -> CGFloat {
        guard let activeTapOrigin else {
            return 0
        }

        let radius = moduleSide * rippleConfiguration.activeTapRadiusInModules
        guard radius > 0 else {
            return 0
        }

        let distance = hypot(point.x - activeTapOrigin.x, point.y - activeTapOrigin.y)
        guard distance < radius else {
            return 0
        }

        let normalizedDistance = distance / radius
        return (1 - normalizedDistance).clamped(to: 0 ... maximumInfluence)
    }

    static func combinedInfluence(
        at point: CGPoint,
        activeTapOrigin: CGPoint?,
        ripples: [QrCodeRipple],
        date: Date,
        bounds: CGRect,
        moduleSide: CGFloat,
        rippleConfiguration: QrCodeRippleConfiguration
    ) -> CGFloat {
        let tapInfluence = influence(
            at: point,
            activeTapOrigin: activeTapOrigin,
            moduleSide: moduleSide,
            rippleConfiguration: rippleConfiguration
        )
        let rippleInfluence = QrCodeRippleEffect.combinedInfluence(
            at: point,
            ripples: ripples,
            date: date,
            bounds: bounds,
            moduleSide: moduleSide,
            rippleConfiguration: rippleConfiguration
        )
        return (tapInfluence + rippleInfluence).clamped(to: 0 ... maximumInfluence)
    }
}
