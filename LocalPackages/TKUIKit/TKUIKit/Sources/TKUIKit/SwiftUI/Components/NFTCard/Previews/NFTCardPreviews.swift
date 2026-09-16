import SwiftUI
import UIKit

public struct NFTCardPreviews: View {
    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                section(title: "Medium") {
                    cardsRow(imageSize: .medium)
                }

                section(title: "Small") {
                    cardsRow(imageSize: .small)
                }

                section(title: "Shimmer") {
                    HStack(alignment: .top, spacing: Layout.cardSpacing) {
                        NFTCard(config: .shimmer, imageSize: .medium)
                        NFTCard(config: .shimmer, imageSize: .small)
                    }
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tkImmediateButtonPresses()
        .debugPreview(background: .page)
    }
}

private extension NFTCardPreviews {
    enum Layout {
        static let sectionSpacing: CGFloat = 24
        static let cardSpacing: CGFloat = 12
        static let titleSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
    }

    func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.titleSpacing) {
            Text(title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)

            content()
        }
    }

    func cardsRow(imageSize: NFTImageView.Size) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Layout.cardSpacing) {
                ForEach(previewContents) { content in
                    VStack(alignment: .leading, spacing: 8) {
                        NFTCard(
                            content: content,
                            imageSize: imageSize,
                            action: {}
                        )

                        Text(content.id)
                            .textStyle(.body3)
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
        }
    }

    var previewContents: [NFTCardContent] {
        [
            NFTCardContent(
                id: "Default",
                title: "Plush Pepe",
                subtitle: "Telegram Gifts",
                imageSource: .image(previewArtwork(hue: 0.58))
            ),
            NFTCardContent(
                id: "On Sale",
                title: "Mirra Yui",
                subtitle: "Annihilation",
                imageSource: .image(previewArtwork(hue: 0.72)),
                isOnSale: true
            ),
            NFTCardContent(
                id: "Secure Mode",
                title: "Hidden NFT",
                subtitle: "Collection",
                imageSource: .image(previewArtwork(hue: 0.12)),
                isSecureMode: true
            ),
            NFTCardContent(
                id: "Unverified",
                title: "Free Airdrop",
                subtitle: "Unverified",
                subtitleColor: .accentOrange,
                imageSource: .image(previewArtwork(hue: 0.05))
            ),
            NFTCardContent(
                id: "On Sale + Secure",
                title: "Listed NFT",
                subtitle: "Marketplace",
                imageSource: .image(previewArtwork(hue: 0.33)),
                isSecureMode: true,
                isOnSale: true
            ),
            NFTCardContent(
                id: "Long Text",
                title: "Very Long Collectible Name That Truncates",
                subtitle: "Very Long Collection Name That Truncates",
                imageSource: .image(previewArtwork(hue: 0.45))
            ),
            NFTCardContent(
                id: "No Image",
                title: "Placeholder",
                subtitle: "No artwork",
                imageSource: .image(nil)
            ),
        ]
    }

    func previewArtwork(hue: CGFloat) -> UIImage {
        let size = CGSize(width: 360, height: 360)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(hue: hue, saturation: 0.45, brightness: 0.35, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(hue: hue, saturation: 0.55, brightness: 0.75, alpha: 1).setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: 90, y: 90, width: 180, height: 180)
            )
        }
    }
}

#Preview {
    NFTCardPreviews()
        .tkThemed()
}
