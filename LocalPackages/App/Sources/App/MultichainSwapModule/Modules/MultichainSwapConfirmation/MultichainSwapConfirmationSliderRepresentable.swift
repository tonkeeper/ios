import SwiftUI
import TKUIKit
import UIKit

struct MultichainSwapConfirmationSliderRepresentable: UIViewRepresentable {
    let title: NSAttributedString
    let appearance: TKSlider.Appearance
    let isEnabled: Bool
    let resetToken: Int
    let onConfirm: () -> Void

    func makeUIView(context: Context) -> TKSlider {
        let slider = TKSlider()
        slider.appearance = appearance
        slider.title = title
        slider.isEnable = isEnabled
        slider.didConfirm = onConfirm
        slider.swipeHandleAccessibilityIdentifier = "confirm_swipe"
        return slider
    }

    func updateUIView(_ uiView: TKSlider, context: Context) {
        uiView.title = title
        uiView.appearance = appearance
        uiView.isEnable = isEnabled
        uiView.didConfirm = onConfirm
        if context.coordinator.resetToken != resetToken {
            context.coordinator.resetToken = resetToken
            uiView.reset()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(resetToken: resetToken)
    }

    final class Coordinator {
        var resetToken: Int

        init(resetToken: Int) {
            self.resetToken = resetToken
        }
    }
}
