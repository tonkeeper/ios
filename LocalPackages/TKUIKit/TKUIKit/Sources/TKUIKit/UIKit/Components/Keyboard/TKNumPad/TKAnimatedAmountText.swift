import SwiftUI
import UIKit

struct TKAnimatedAmountText: View {
    static let animation = Animation.easeOut(duration: 0.15)

    let text: String
    let font: UIFont
    let color: TKColor

    var body: some View {
        let layout = TKAmountDigits.glyphs(text, font: font)
        let hidden = GlyphAppearance(isVisible: false, font: font)
        let shown = GlyphAppearance(isVisible: true, font: font)
        ZStack(alignment: .leading) {
            ForEach(layout.glyphs, id: \.id) { glyph in
                Text(String(glyph.character))
                    .font(Font(font))
                    .foregroundStyle(color)
                    .fixedSize()
                    .alignmentGuide(.leading) { _ in -glyph.x }
                    .transition(.modifier(active: hidden, identity: shown))
            }
        }
        .animation(Self.animation, value: text)
        .frame(width: layout.width, height: font.lineHeight, alignment: .leading)
    }
}

private struct GlyphAppearance: ViewModifier {
    let isVisible: Bool
    let font: UIFont

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0.5, anchor: UnitPoint(x: 0, y: font.ascender / font.lineHeight))
            .blur(radius: isVisible ? 0 : font.pointSize / 8)
            .opacity(isVisible ? 1 : 0)
    }
}
