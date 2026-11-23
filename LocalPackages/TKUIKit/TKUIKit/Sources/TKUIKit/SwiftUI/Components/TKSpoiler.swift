import SwiftUI
import UIKit

/// `TKSpoilerView`'s particles over whatever it overlays, which sets its size.
public struct TKSpoiler: UIViewRepresentable {
    private let color: TKColor

    public init(color: TKColor = .textPrimary) {
        self.color = color
    }

    public func makeUIView(context: Context) -> TKSpoilerView {
        let view = TKSpoilerView()
        view.isUserInteractionEnabled = false
        view.isOn = true
        return view
    }

    public func updateUIView(_ view: TKSpoilerView, context: Context) {
        let color = color.resolve(context.environment.tkPalette)
        // A new color rebuilds the emitter, which restarts the particles.
        guard color != context.coordinator.color else { return }
        context.coordinator.color = color
        view.spoilerColor = UIColor(color)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        var color: Color?
    }
}
