import SwiftUI

public extension Text {
    /// `Text.tracking` exists from iOS 14, while its `View` counterpart is iOS 16 only, so a `Text`
    /// receiver takes this overload and gets the design letter-spacing on every supported version.
    func textStyle(_ textStyle: TKTextStyle) -> some View {
        tracking(textStyle.letterSpacing)
            .sizedByLineHeight(textStyle)
    }
}

public extension View {
    func textStyle(_ textStyle: TKTextStyle) -> some View {
        trackedIfAvailable(textStyle.letterSpacing)
            .sizedByLineHeight(textStyle)
    }
}

private extension View {
    /// `Text` reports the font's own line box, while the design system sizes text by `lineHeight`
    /// the way Figma does. `lineSpacing` only separates wrapped lines, so the leading is split
    /// across the outer edges too: the frame then measures `lineHeight` per line at any line count,
    /// and callers can use the paddings straight from the design.
    func sizedByLineHeight(_ textStyle: TKTextStyle) -> some View {
        font(Font(textStyle.font))
            .lineSpacing(textStyle.lineSpacing)
            .padding(.vertical, textStyle.lineSpacing / 2)
    }

    @ViewBuilder
    func trackedIfAvailable(_ letterSpacing: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            tracking(letterSpacing)
        } else {
            self
        }
    }
}
