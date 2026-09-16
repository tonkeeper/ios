import KeeperCore
import TKUIKit
import UIKit

enum WalletMultichainPresentation {
    static let badgeTitle = "MULTICHAIN"

    static var badgeTagConfiguration: TKTagView.Configuration {
        .accentTag(text: badgeTitle, color: .Accent.blue)
    }

    static var badgeTagSwiftUIConfiguration: TKTagSwiftUIViewConfig {
        .accentTag(text: badgeTitle, accent: .accentBlue)
    }

    private static let networksDisplayOrder: [MultichainChain] = [.ton, .btc, .eth, .bsc, .tron, .base, .arb]

    static func networksRowImage(chains: [MultichainChain], maxVisibleCount: Int = 4) -> UIImage {
        let iconSize: CGFloat = 18
        let cutoutWidth: CGFloat = 2
        let step = iconSize - cutoutWidth
        let orderedChains = networksDisplayOrder.filter(chains.contains)
            + chains.filter { !networksDisplayOrder.contains($0) }
        let visibleChains = Array(orderedChains.prefix(maxVisibleCount))
        let hasMore = orderedChains.count > maxVisibleCount
        let slotsCount = visibleChains.count + (hasMore ? 1 : 0)
        guard slotsCount > 0 else { return UIImage() }

        let size = CGSize(width: iconSize + CGFloat(slotsCount - 1) * step, height: iconSize)
        let style = TKThemeManager.shared.theme.userInterfaceStyle
        let traits = UITraitCollection(traitsFrom: [
            UIScreen.main.traitCollection,
            UITraitCollection(
                userInterfaceStyle: style == .unspecified
                    ? UIScreen.main.traitCollection.userInterfaceStyle
                    : style
            ),
        ])
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        var image = UIImage()
        traits.performAsCurrent {
            image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                drawNetworksRow(
                    context: context,
                    visibleChains: visibleChains,
                    slotsCount: slotsCount,
                    iconSize: iconSize,
                    cutoutWidth: cutoutWidth,
                    step: step
                )
            }
        }
        return image
    }

    private static func drawNetworksRow(
        context: UIGraphicsImageRendererContext,
        visibleChains: [MultichainChain],
        slotsCount: Int,
        iconSize: CGFloat,
        cutoutWidth: CGFloat,
        step: CGFloat
    ) {
        for index in stride(from: slotsCount - 1, through: 0, by: -1) {
            let rect = CGRect(x: CGFloat(index) * step, y: 0, width: iconSize, height: iconSize)
            let cutoutRect = rect.insetBy(dx: -cutoutWidth, dy: -cutoutWidth)
            context.cgContext.saveGState()
            UIBezierPath(ovalIn: cutoutRect).addClip()
            context.cgContext.clear(cutoutRect)
            context.cgContext.restoreGState()

            context.cgContext.saveGState()
            UIBezierPath(ovalIn: rect).addClip()
            if index < visibleChains.count {
                visibleChains[index].tokenIcon20.draw(in: rect)
            } else {
                UIColor.Background.contentTint.setFill()
                context.cgContext.fill(rect)
                let ellipsisSize: CGFloat = 12
                let ellipsisRect = CGRect(
                    x: rect.midX - ellipsisSize / 2,
                    y: rect.midY - ellipsisSize / 2,
                    width: ellipsisSize,
                    height: ellipsisSize
                )
                UIImage.TKUIKit.Icons.Size16.ellipses
                    .withTintColor(.Icon.secondary)
                    .draw(in: ellipsisRect)
            }
            context.cgContext.restoreGState()
        }
    }
}
