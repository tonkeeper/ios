import UIKit

enum TKTabBarStyle: Equatable {
    case custom
    case system

    /// A normal iPhone never reports a vertical bar edge. Duo does, including after the
    /// bar has already moved, so a lock keeps Duo on the system bar when the edge goes away.
    static func resolve(verticalBarEdgeIsSpecified: Bool, systemTabBarLocked: Bool) -> TKTabBarStyle {
        if systemTabBarLocked || verticalBarEdgeIsSpecified {
            return .system
        }
        return .custom
    }
}
