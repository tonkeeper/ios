import UIKit

public struct QrCodeRippleConfiguration: Equatable, Sendable {
    var animationDuration: TimeInterval
    var ringWidthInModules: CGFloat
    var activeTapRadiusInModules: CGFloat
    var maxDotDiameterReduction: CGFloat
    var maxFinderPatternOpacityReduction: CGFloat
    var maxSimultaniousRipplesCount: Int

    public init(
        animationDuration: TimeInterval? = nil,
        ringWidthInModules: CGFloat? = nil,
        activeTapRadiusInModules: CGFloat? = nil,
        maxDotDiameterReduction: CGFloat? = nil,
        maxFinderPatternOpacityReduction: CGFloat? = nil,
        maxSimultaniousRipplesCount: Int? = nil
    ) {
        self.animationDuration = max(
            animationDuration ?? Constants.animationDuration,
            Constants.minAnimationDuration
        )
        self.ringWidthInModules = max(
            ringWidthInModules ?? Constants.ringWidthInModules,
            Constants.minRingWidthInModules
        )
        self.activeTapRadiusInModules = max(
            activeTapRadiusInModules ?? Constants.activeTapRadiusInModules,
            Constants.minActiveTapRadiusInModules
        )
        self.maxDotDiameterReduction = max(
            maxDotDiameterReduction ?? Constants.maxDotDiameterReduction,
            Constants.minDotDiameterReduction
        )
        self.maxFinderPatternOpacityReduction = max(
            maxFinderPatternOpacityReduction ?? Constants.maxFinderPatternOpacityReduction,
            Constants.minFinderPatternOpacityReduction
        )
        self.maxSimultaniousRipplesCount = max(
            maxSimultaniousRipplesCount ?? Constants.maxSimultaniousRipplesCount,
            Constants.minSimultaniousRipplesCount
        )
    }
}

public extension QrCodeRippleConfiguration {
    static var `default`: QrCodeRippleConfiguration {
        QrCodeRippleConfiguration()
    }
}

extension QrCodeRippleConfiguration {
    enum Constants {
        static let minAnimationDuration: TimeInterval = 0.1
        static let animationDuration: TimeInterval = 1

        static let minRingWidthInModules: CGFloat = 1
        static let ringWidthInModules: CGFloat = 4

        static let minActiveTapRadiusInModules: CGFloat = 1
        static let activeTapRadiusInModules: CGFloat = 7

        static let minDotDiameterReduction: CGFloat = 0
        static let maxDotDiameterReduction: CGFloat = 0.5

        static let minFinderPatternOpacityReduction: CGFloat = 0
        static let maxFinderPatternOpacityReduction: CGFloat = 0.5

        static let minSimultaniousRipplesCount: Int = 1
        static let maxSimultaniousRipplesCount: Int = 100
    }
}
