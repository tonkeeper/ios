import SwiftUI

extension View {
    /// The Liquid Glass backing of a control: the control has no fill of its own, its colour tints the glass.
    @ViewBuilder
    func tkGlassBackground(tint: Color, in shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(tint), in: shape)
        } else {
            background(shape.fill(tint))
        }
    }

    /// Pins the liquid glass variant for one preview through the environment, leaving the app's flag alone.
    func tkPreviewLiquidGlass(_ isEnabled: Bool) -> some View {
        environment(\.tkPreviewLiquidGlass, isEnabled)
    }
}

extension EnvironmentValues {
    /// Set only by `tkPreviewLiquidGlass`; nil follows `TKLiquidGlass`.
    var tkPreviewLiquidGlass: Bool? {
        get { self[PreviewLiquidGlassKey.self] }
        set { self[PreviewLiquidGlassKey.self] = newValue }
    }
}

private struct PreviewLiquidGlassKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}
