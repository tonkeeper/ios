import CFNetwork
import Foundation

public enum VPNStatus {
    /// Keep this heuristic conservative to avoid flagging system tunnels like Wi-Fi calling.
    static let vpnInterfaceMarkers = ["ppp", "tap", "tun", "utun"]

    public static func isVPNConnected() -> Bool {
        guard
            let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
            let scoped = proxySettings["__SCOPED__"] as? [String: Any]
        else {
            return false
        }

        return scoped.keys.contains { key in
            vpnInterfaceMarkers.contains { key.range(of: $0, options: .caseInsensitive) != nil }
        }
    }
}
