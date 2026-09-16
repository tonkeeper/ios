import CoreImage
import UIKit

private extension CGFloat {
    func pixelAligned(scale: CGFloat) -> CGFloat {
        floor(self * scale) / scale
    }

    func pixelAlignedNonZero(scale: CGFloat) -> CGFloat {
        Swift.max(1 / scale, pixelAligned(scale: scale))
    }
}

struct QrCodeMatrixGeometry {
    let moduleSide: CGFloat
    let finderPatterns: [QrCodeFinderPattern]

    private let origin: CGPoint
    private let quietZoneInModules: Int
    private let dotDiameterRatio: CGFloat
    private let screenScale: CGFloat
    private let centerCutoutModuleRect: QrCodeModuleRect?

    init(
        size: CGSize,
        matrix: QrCodeMatrix,
        configuration: QrCodeGeneratorConfiguration,
        screenScale: CGFloat
    ) {
        let side = min(size.width, size.height)
        let quietZoneInModules = configuration.quietZoneInModules
        let totalModuleCount = max(matrix.width, matrix.height) + quietZoneInModules * 2
        let rawModulePixels = side * screenScale / CGFloat(totalModuleCount)
        let modulePixels = max(1, floor(rawModulePixels))
        self.moduleSide = modulePixels / screenScale
        let qrSide = moduleSide * CGFloat(totalModuleCount)
        self.quietZoneInModules = quietZoneInModules
        self.screenScale = screenScale
        self.dotDiameterRatio = Self.resolvedDotDiameterRatio(
            configuration.dotDiameterRatio,
            moduleSide: moduleSide
        )
        self.origin = CGPoint(
            x: (
                (size.width - qrSide) / 2
            ).pixelAligned(scale: screenScale),
            y: (
                (size.height - qrSide) / 2
            ).pixelAligned(scale: screenScale)
        )
        self.finderPatterns = matrix.finderPatterns

        if let centerCutoutSize = configuration.centerCutoutSize {
            let cutoutWidthModules = Self.cutoutModuleCount(
                points: centerCutoutSize.width,
                moduleSide: moduleSide,
                totalModuleCount: totalModuleCount
            )
            let cutoutHeightModules = Self.cutoutModuleCount(
                points: centerCutoutSize.height,
                moduleSide: moduleSide,
                totalModuleCount: totalModuleCount
            )
            let minX = (totalModuleCount - cutoutWidthModules) / 2
            let minY = (totalModuleCount - cutoutHeightModules) / 2
            self.centerCutoutModuleRect = QrCodeModuleRect(
                minX: minX,
                minY: minY,
                maxX: minX + cutoutWidthModules - 1,
                maxY: minY + cutoutHeightModules - 1
            )
        } else {
            self.centerCutoutModuleRect = nil
        }
    }
}

extension QrCodeMatrixGeometry {
    func moduleRect(x: Int, y: Int) -> CGRect {
        totalModuleRect(x: x + quietZoneInModules, y: y + quietZoneInModules, width: 1, height: 1)
    }

    func dotRect(x: Int, y: Int, diameterMultiplier: CGFloat) -> CGRect {
        let rect = moduleRect(x: x, y: y)
        let ratio = (dotDiameterRatio * diameterMultiplier).clamped(to: 0 ... 1)
        let diameter = (rect.width * ratio).pixelAlignedNonZero(scale: screenScale)
        return CGRect(
            x: (rect.midX - diameter / 2).pixelAligned(scale: screenScale),
            y: (rect.midY - diameter / 2).pixelAligned(scale: screenScale),
            width: diameter,
            height: diameter
        )
    }

    func finderPatternRect(_ pattern: QrCodeFinderPattern, inset: Int) -> CGRect {
        totalModuleRect(
            x: pattern.x + quietZoneInModules + inset,
            y: pattern.y + quietZoneInModules + inset,
            width: pattern.size - inset * 2,
            height: pattern.size - inset * 2
        )
    }

    func isFinderPatternModule(x: Int, y: Int) -> Bool {
        finderPatterns.contains { pattern in
            pattern.contains(x: x, y: y)
        }
    }

    func isCenterCutoutModule(x: Int, y: Int) -> Bool {
        guard let centerCutoutModuleRect else { return false }
        let totalX = x + quietZoneInModules
        let totalY = y + quietZoneInModules
        return centerCutoutModuleRect.contains(x: totalX, y: totalY)
    }

    private func totalModuleRect(x: Int, y: Int, width: Int, height: Int) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(x) * moduleSide,
            y: origin.y + CGFloat(y) * moduleSide,
            width: CGFloat(width) * moduleSide,
            height: CGFloat(height) * moduleSide
        )
    }

    private static func resolvedDotDiameterRatio(_ ratio: CGFloat, moduleSide: CGFloat) -> CGFloat {
        if moduleSide < 4.5 {
            return QrCodeConstants.smallModuleDotDiameterRatio
        }
        return ratio.clamped(to: 0 ... 1)
    }

    private static func cutoutModuleCount(
        points: CGFloat,
        moduleSide: CGFloat,
        totalModuleCount: Int
    ) -> Int {
        let clampedPoints = points.clamped(to: 0 ... CGFloat(totalModuleCount) * moduleSide)
        return Int(ceil(clampedPoints / moduleSide)).clamped(to: 1 ... totalModuleCount)
    }
}
