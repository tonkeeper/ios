import Foundation

/// An error that provides a safe, structured description for diagnostic logs.
public protocol LoggableError: Error {
    var logDescription: String { get }
}

public extension Error {
    var logDescription: String {
        if let error = self as? any LoggableError {
            return error.logDescription
        }
        // `URLError` is bridged, so inside an `any Error` box its dynamic type is `NSError` and
        // the conformance below never matches. The bridging cast is what reaches it.
        if let error = self as? URLError {
            return error.logDescription
        }

        let error = self as NSError
        return LogDescription(type: type(of: self))
            .with("case", enumCaseName)
            .with("domain", error.domain)
            .with("code", error.code)
            .with("underlying", error: error.userInfo[NSUnderlyingErrorKey] as? any Error)
            .text
    }
}

private extension Error {
    /// The case label alone. Payloads and `LocalizedError` messages stay out of the default
    /// rendering — an error opts into exposing them by conforming to `LoggableError`.
    var enumCaseName: String? {
        let mirror = Mirror(reflecting: self)
        guard mirror.displayStyle == .enum else {
            return nil
        }
        return mirror.children.first?.label ?? String(describing: self)
    }
}

extension DecodingError: LoggableError {
    public var logDescription: String {
        let description = LogDescription(type: DecodingError.self)
        switch self {
        case let .typeMismatch(expected, context):
            return description
                .with("case", "typeMismatch")
                .with("expected", "\(expected)")
                .with("path", context.codingPath.logDescription)
                .text
        case let .valueNotFound(expected, context):
            return description
                .with("case", "valueNotFound")
                .with("expected", "\(expected)")
                .with("path", context.codingPath.logDescription)
                .text
        case let .keyNotFound(key, context):
            return description
                .with("case", "keyNotFound")
                .with("key", key.stringValue)
                .with("path", context.codingPath.logDescription)
                .text
        case let .dataCorrupted(context):
            return description
                .with("case", "dataCorrupted")
                .with("reason", context.debugDescription)
                .with("path", context.codingPath.logDescription)
                .text
        @unknown default:
            return description.with("case", "unknown").text
        }
    }
}

extension URLError: LoggableError {
    public var logDescription: String {
        LogDescription(type: URLError.self)
            .with("code", errorCode)
            .with("reason", Self.reason(for: code))
            .with("failingURL", failingURL?.loggedPath)
            .text
    }

    private static func reason(for code: Code) -> String {
        switch code {
        case .cancelled: return "cancelled"
        case .timedOut: return "timedOut"
        case .notConnectedToInternet: return "notConnectedToInternet"
        case .networkConnectionLost: return "networkConnectionLost"
        case .cannotFindHost: return "cannotFindHost"
        case .cannotConnectToHost: return "cannotConnectToHost"
        case .dnsLookupFailed: return "dnsLookupFailed"
        case .secureConnectionFailed: return "secureConnectionFailed"
        case .serverCertificateUntrusted: return "serverCertificateUntrusted"
        case .appTransportSecurityRequiresSecureConnection: return "appTransportSecurityRequiresSecureConnection"
        case .internationalRoamingOff: return "internationalRoamingOff"
        case .dataNotAllowed: return "dataNotAllowed"
        case .callIsActive: return "callIsActive"
        case .badServerResponse: return "badServerResponse"
        case .zeroByteResource: return "zeroByteResource"
        case .cannotParseResponse: return "cannotParseResponse"
        case .resourceUnavailable: return "resourceUnavailable"
        case .unsupportedURL, .badURL: return "badURL"
        default: return "other"
        }
    }
}

extension CancellationError: LoggableError {
    public var logDescription: String {
        LogDescription(type: CancellationError.self).text
    }
}

private extension [CodingKey] {
    var logDescription: String? {
        isEmpty ? nil : map(\.stringValue).joined(separator: ".")
    }
}

private extension URL {
    /// Host and path only — query values carry search terms and identifiers.
    var loggedPath: String {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return path
        }
        return [components.host, components.path]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined()
    }
}
