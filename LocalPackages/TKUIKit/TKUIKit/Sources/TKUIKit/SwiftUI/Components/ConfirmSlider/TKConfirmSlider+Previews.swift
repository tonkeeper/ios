import SwiftUI

@available(iOS 17.0, *)
#Preview("Slider", traits: .fixedLayout(width: 358, height: 64)) {
    TKConfirmSlider {}
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("States", traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        TKConfirmSlider {}
        TKConfirmSlider(appearance: .warning) {}
        TKConfirmSlider(appearance: .danger) {}
        TKConfirmSlider(isEnabled: false) {}
    }
    .frame(width: 358)
    .padding(16)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Light", traits: .fixedLayout(width: 358, height: 64)) {
    TKConfirmSlider {}
        .background(.backgroundPage)
        .tkPreviewTheme(.light)
}
