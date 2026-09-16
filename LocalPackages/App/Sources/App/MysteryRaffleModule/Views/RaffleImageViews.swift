import Kingfisher
import SwiftUI
import TKUIKit
import UIKit

enum RaffleKingfisherSource {
    static func source(_ url: URL) -> Kingfisher.Source {
        url.isFileURL ? .provider(LocalFileImageDataProvider(fileURL: url)) : .network(url)
    }
}

struct TemplateIcon: View {
    let image: UIImage
    let tint: TKColor
    let size: CGFloat

    var body: some View {
        SwiftUI.Image(uiImage: image)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(tint)
            .frame(width: size, height: size)
    }
}

struct RaffleImageView: View {
    let source: RaffleImageSource
    let size: CGFloat
    var tint: TKColor = .iconSecondary

    var body: some View {
        switch source {
        case let .symbol(symbol):
            TemplateIcon(image: symbol.image, tint: tint, size: size)
        case let .url(url):
            if let url {
                KFImage(source: RaffleKingfisherSource.source(url))
                    .resizable()
                    .placeholder { ShimmerSwiftUIView(config: .init(color: .backgroundContentTint)) }
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                ShimmerSwiftUIView(config: .init(color: .backgroundContentTint))
                    .frame(width: size, height: size)
            }
        }
    }
}

struct RaffleAccentBadge: View {
    @Environment(\.tkPalette) private var palette

    let symbol: RaffleSymbol
    let accent: RaffleAccent
    var isAccented: Bool = true

    var body: some View {
        ZStack {
            (isAccented ? accent.color : .backgroundContentTint)
                .resolve(palette)
                .opacity(isAccented ? 0.12 : 1)
            TemplateIcon(
                image: symbol.image,
                tint: isAccented ? accent.color : .iconTertiary,
                size: 28
            )
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Accent-tinted pill above the hero title ("Early Access" / "You're in!" / …).
struct RaffleStatusPill: View {
    let badge: RaffleStatusBadge

    private var tint: TKColor {
        badge.accent.color
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = badge.icon {
                TemplateIcon(image: icon.image, tint: tint, size: 18)
            }
            Text(badge.text)
                .textStyle(.label2)
                .foregroundStyle(tint)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// 44pt neutral icon container used in the tickets-history rows.
struct RaffleHistoryBadge: View {
    @Environment(\.tkPalette) private var palette

    let symbol: RaffleSymbol

    var body: some View {
        ZStack {
            palette.background.contentTint
            TemplateIcon(image: symbol.image, tint: .iconSecondary, size: 28)
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Top-right close button over the hero (transparent header so the glow shows
/// through). Matches `Header / Close`: 32pt rounded square, secondary fill.
struct RaffleCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TemplateIcon(image: .TKUIKit.Icons.Size16.close, tint: .buttonSecondaryForeground, size: 16)
                .padding(8)
                .background(.buttonSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
