import UIKit

/// - `custom`: `TKTabBarView` drawn over the system bar.
/// - `systemHorizontal`: the system bar (liquid glass on iOS 26) with the app's additions on top of it.
/// - `systemVertical`: the system bar while Duo shows it vertically. It takes its own touches and
///   mirrors the bar's subviews into the content, so it gets no long press and no hint anchor;
///   the animated icons still play, since they go through the tab bar items' images.
public enum TKTabBarStyle: Equatable {
    case custom
    case systemHorizontal
    case systemVertical

    /// Duo reports a vertical bar edge only while the bar is vertical. In the other orientations
    /// `keepsSystemBar` holds it on the system bar: set by Duo's hinge or by a system bar already
    /// installed, because the custom bar cannot come back once dropped.
    static func resolve(
        verticalBarEdgeIsSpecified: Bool,
        keepsSystemBar: Bool,
        liquidGlassEnabled: Bool
    ) -> TKTabBarStyle {
        if verticalBarEdgeIsSpecified {
            return .systemVertical
        }
        if keepsSystemBar || liquidGlassEnabled {
            return .systemHorizontal
        }
        return .custom
    }
}
