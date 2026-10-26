import Foundation

/// Hosts of a MoonPay Platform deployment. Test versus live mode is decided by the secret key
/// used to create the session (`sk_test_` / `sk_live_`), not by the host, so both environments
/// load frames from the same origin.
public struct MoonPayEnvironment: Hashable, Sendable {
    public let frameOrigin: URL
    public let apiBaseURL: URL

    public init(frameOrigin: URL, apiBaseURL: URL) {
        self.frameOrigin = frameOrigin
        self.apiBaseURL = apiBaseURL
    }

    public static let production = MoonPayEnvironment(
        frameOrigin: URL(string: "https://platform.moonpay.com")!,
        apiBaseURL: URL(string: "https://api.moonpay.com")!
    )

    public static let sandbox = MoonPayEnvironment(
        frameOrigin: URL(string: "https://platform.moonpay.com")!,
        apiBaseURL: URL(string: "https://api.moonpay.dev")!
    )
}

public enum MoonPayTheme: String, Codable, CaseIterable, Sendable {
    case dark
    case light
}
