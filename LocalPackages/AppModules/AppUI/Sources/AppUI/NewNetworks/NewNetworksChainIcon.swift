import SwiftUI
import TKUIKit
import UIKit

/// A chain's logo on the orbit: in colour, or in the grey loading look from the design — a
/// content-tint disc with the glyph in the secondary icon colour. The glyph is told apart from the
/// logo's background by luminance; a logo whose glyph is darker than its background (Robinhood) is
/// inverted first so the glyph lights up.
struct NewNetworksChainIcon: View {
    enum Style {
        case colored
        case grey
    }

    let chain: NewNetworksScreenState.Chain
    let style: Style
    let size: CGFloat
    let borderWidth: CGFloat

    var body: some View {
        ZStack {
            switch style {
            case .colored:
                logo
            case .grey:
                Circle()
                    .fill(.backgroundContentTint)
                TKColor.iconSecondary
                    .mask { logo.modifier(GlyphMask(luminance: chain.luminance)) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.backgroundPage, lineWidth: borderWidth))
    }

    private var logo: some View {
        Image(uiImage: chain.icon)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

/// Luminance on the glyph's side of the midpoint between glyph and background becomes alpha; the
/// steep contrast keeps the background out whatever its colour.
private struct GlyphMask: ViewModifier {
    let luminance: NewNetworksGlyphLuminance

    func body(content: Content) -> some View {
        let invert = luminance.glyph < luminance.background
        let background = invert ? 1 - luminance.background : luminance.background
        let glyph = invert ? 1 - luminance.glyph : luminance.glyph
        let threshold = (background + glyph) / 2
        let contrast = min(20, 4 / max(0.2, glyph - background))
        Group {
            if invert {
                content.colorInvert()
            } else {
                content
            }
        }
        // `contrast` maps a channel to (v - 0.5) * c + 0.5; the shift moves the threshold, so the
        // alpha below is c * (luminance - threshold).
        .contrast(contrast)
        .brightness(contrast * (0.5 - threshold) - 0.5)
        .luminanceToAlpha()
    }
}

/// Average luminance of a logo's middle, where its glyph is, and of a ring near its edge, where
/// only its background is.
struct NewNetworksGlyphLuminance: Equatable {
    let glyph: Double
    let background: Double
}

extension UIImage {
    /// Drawn once at a small size. A ring near the edge, rather than the whole logo, stands for
    /// the background: a big glyph (Avalanche) would skew an average over the whole logo.
    var glyphLuminance: NewNetworksGlyphLuminance {
        let side = 48
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return NewNetworksGlyphLuminance(glyph: 1, background: 0)
        }
        UIGraphicsPushContext(context)
        draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        UIGraphicsPopContext()
        guard let data = context.data else {
            return NewNetworksGlyphLuminance(glyph: 1, background: 0)
        }
        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side * 4)

        let center = Double(side) / 2
        var glyph = LuminanceSum()
        var background = LuminanceSum()
        for y in 0 ..< side {
            for x in 0 ..< side {
                let dx = Double(x) + 0.5 - center
                let dy = Double(y) + 0.5 - center
                let distance = sqrt(dx * dx + dy * dy) / center
                let offset = (y * side + x) * 4
                let alpha = Double(pixels[offset + 3])
                guard alpha >= 128 else { continue }
                let luminance = (
                    0.2126 * Double(pixels[offset])
                        + 0.7152 * Double(pixels[offset + 1])
                        + 0.0722 * Double(pixels[offset + 2])
                ) / alpha
                if distance < 0.4 {
                    glyph.add(luminance)
                } else if (0.8 ... 0.95).contains(distance) {
                    background.add(luminance)
                }
            }
        }
        return NewNetworksGlyphLuminance(glyph: glyph.average ?? 1, background: background.average ?? 0)
    }
}

private struct LuminanceSum {
    private var sum = 0.0
    private var count = 0

    var average: Double? {
        count > 0 ? sum / Double(count) : nil
    }

    mutating func add(_ luminance: Double) {
        sum += luminance
        count += 1
    }
}
