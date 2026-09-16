import SwiftUI

struct SwapPairAvatarView: View {
    let left: AssetAvatarViewImageSource
    let right: AssetAvatarViewImageSource

    var body: some View {
        HStack(spacing: Layout.spacing) {
            AssetAvatarView(
                imageSource: left,
                size: Layout.avatarSize,
                chainIconPosition: .leading
            )
            .mask {
                CutoutShape(
                    overlap: 8,
                    gap: 4,
                    hasNext: true
                )
                .fill(style: FillStyle(eoFill: true))
            }
            AssetAvatarView(
                imageSource: right,
                size: Layout.avatarSize,
                chainIconPosition: .trailing
            )
        }
    }

    enum Layout {
        static let spacing: CGFloat = -8
        static let avatarSize: AssetAvatarView.Size = .large
    }

    struct CutoutShape: Shape {
        let overlap: CGFloat
        let gap: CGFloat
        let hasNext: Bool

        func path(in rect: CGRect) -> Path {
            var path = Path()

            let size = Layout.avatarSize.configuration.imageSize

            let radius = size / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)

            // Main avatar circle
            path.addRect(
                CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: size,
                    height: size
                ).insetBy(
                    dx: -max(0, Layout.avatarSize.configuration.chainIconOffsetX),
                    dy: -max(0, Layout.avatarSize.configuration.chainIconOffsetY)
                )
            )

            guard hasNext else { return path }

            let nextCenterX = center.x + size - overlap
            let cutoutRadius = radius + gap

            path.addEllipse(in: CGRect(
                x: nextCenterX - cutoutRadius,
                y: center.y - cutoutRadius,
                width: cutoutRadius * 2,
                height: cutoutRadius * 2
            ))

            return path
        }
    }
}
