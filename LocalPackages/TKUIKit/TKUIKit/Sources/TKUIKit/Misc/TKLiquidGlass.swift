import Foundation

/// Whether shared components draw their liquid glass variant. The app sets `isFeatureEnabled` from its
/// `liquidGlassEnabled` flag; components read `isEnabled`, which stays off below iOS 26 so a component
/// that only changes metrics cannot switch to the new look there.
@MainActor
public enum TKLiquidGlass {
    public static var isFeatureEnabled = false

    public static var isEnabled: Bool {
        isEnabled(previewPin: nil)
    }

    /// `isEnabled`, unless a SwiftUI preview pins the variant (`tkPreviewLiquidGlass`).
    static func isEnabled(previewPin: Bool?) -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        return previewPin ?? isFeatureEnabled
    }
}
