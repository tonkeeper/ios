import SwiftUI
import UIKit

@available(iOS 17.0, *)
#Preview("Deep Blue", traits: .fixedLayout(width: 390, height: 304)) {
    NumPadPreviewHost(presets: [])
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Presets", traits: .fixedLayout(width: 390, height: 356)) {
    NumPadPreviewHost(presets: ["25%", "50%", "75%", "MAX"])
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Presets and button", traits: .fixedLayout(width: 390, height: 393)) {
    NumPadPreviewHost(
        presets: ["50€", "100€", "500€", "MAX"],
        button: TKNumPadButton(title: "Continue") {}
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Disabled button", traits: .fixedLayout(width: 390, height: 393)) {
    NumPadPreviewHost(
        presets: ["50€", "100€", "500€", "MAX"],
        button: TKNumPadButton(title: "Minimum amount €20", isEnabled: false) {}
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
private struct NumPadPreviewHost: UIViewRepresentable {
    let presets: [String]
    var button: TKNumPadButton?

    func makeCoordinator() -> UITextField {
        UITextField()
    }

    func makeUIView(context: Context) -> TKNumPadView {
        TKPreview.pinTheme(.deepBlue)
        let numPad = TKNumPadView(textField: context.coordinator)
        numPad.presets = presets.map { TKNumPadPreset(title: $0) {} }
        numPad.button = button
        return numPad
    }

    func updateUIView(_ uiView: TKNumPadView, context: Context) {}
}
