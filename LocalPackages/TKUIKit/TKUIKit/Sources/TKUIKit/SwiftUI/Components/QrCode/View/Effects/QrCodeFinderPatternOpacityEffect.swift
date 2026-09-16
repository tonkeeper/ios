import UIKit

enum QrCodeFinderPatternOpacityEffect {
    static func opacity(
        influence: CGFloat,
        rippleConfiguration: QrCodeRippleConfiguration
    ) -> Double {
        let clampedInfluence = influence.clamped(
            to: 0 ... QrCodeTapEffect.maximumInfluence
        )
        let opacity = 1 - rippleConfiguration.maxFinderPatternOpacityReduction * clampedInfluence
        return Double(
            opacity.clamped(to: 0 ... 1)
        )
    }
}
