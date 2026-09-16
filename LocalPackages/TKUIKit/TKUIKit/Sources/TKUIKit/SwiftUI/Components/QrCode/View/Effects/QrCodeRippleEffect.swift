import UIKit

enum QrCodeRippleEffect {
    static let maximumInfluence: CGFloat = 1

    static func combinedInfluence(
        at point: CGPoint,
        ripples: [QrCodeRipple],
        date: Date,
        bounds: CGRect,
        moduleSide: CGFloat,
        rippleConfiguration: QrCodeRippleConfiguration
    ) -> CGFloat {
        let totalInfluence = ripples.reduce(0 as CGFloat) { partialResult, ripple in
            partialResult + influence(
                at: point,
                ripple: ripple,
                date: date,
                bounds: bounds,
                moduleSide: moduleSide,
                rippleConfiguration: rippleConfiguration
            )
        }
        return totalInfluence.clamped(to: 0 ... maximumInfluence)
    }

    private static func influence(
        at point: CGPoint,
        ripple: QrCodeRipple,
        date: Date,
        bounds: CGRect,
        moduleSide: CGFloat,
        rippleConfiguration: QrCodeRippleConfiguration
    ) -> CGFloat {
        let elapsed = date.timeIntervalSince(ripple.startDate)
        guard elapsed >= 0, elapsed < rippleConfiguration.animationDuration else {
            return 0
        }

        let farthestRadius = farthestCornerDistance(from: ripple.origin, in: bounds)
        guard farthestRadius > 0 else {
            return 0
        }

        let progress = CGFloat(elapsed / rippleConfiguration.animationDuration)
        let radius = farthestRadius * progress
        let distance = hypot(point.x - ripple.origin.x, point.y - ripple.origin.y)
        let ringWidth = max(moduleSide * rippleConfiguration.ringWidthInModules, 1)
        let ringDistance = abs(distance - radius)
        guard ringDistance <= ringWidth else {
            return 0
        }

        let spatialInfluence = 1 - ringDistance / ringWidth
        let temporalInfluence = sin(CGFloat.pi * progress)
        return (spatialInfluence * temporalInfluence).clamped(to: 0 ... maximumInfluence)
    }

    private static func farthestCornerDistance(from point: CGPoint, in bounds: CGRect) -> CGFloat {
        [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.minX, y: bounds.maxY),
            CGPoint(x: bounds.maxX, y: bounds.maxY),
        ]
        .map { hypot($0.x - point.x, $0.y - point.y) }
        .max() ?? 0
    }
}
