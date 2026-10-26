import FirebaseAnalytics
import Foundation
import Network

protocol TonConnectReturnStrategyLogging {
    func logReturnStrategy(_ returnStrategy: TonConnectReturnStrategy)
}

public final class FirebaseTonConnectReturnStrategyLogger: TonConnectReturnStrategyLogging {
    public init() {}

    public func logReturnStrategy(_ returnStrategy: TonConnectReturnStrategy) {
        let event = TonConnectReturnStrategyEvent(returnStrategy)
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
}

struct TonConnectReturnStrategyEvent: Equatable {
    let name: String
    let parameters: [String: NSObject]

    init(_ strategy: TonConnectReturnStrategy) {
        name = "tc_return_strategy_seen"

        parameters = [
            "strategy_scheme": strategy.scheme as NSString,
            "strategy_host": strategy.host as NSString,
        ]
    }
}

public struct TonConnectReturnStrategy: Equatable {
    public let action: Action
    public let scheme: String
    public let host: String

    public enum Action: Equatable {
        case drop(DropReason)
        case open(URL)
        case openInAppURL(URL)
    }

    public enum DropReason: String {
        case unavailable
        case noReturn
        case localAddress
    }

    private enum HostKind {
        case `public`
        case localhost
        case privateIP
        case unavailable
    }

    public init(_ returnStrategy: String?) {
        guard let returnStrategy else {
            self.init(action: .drop(.unavailable), scheme: "none", host: "none")
            return
        }

        let trimmed = returnStrategy.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        switch lowercased {
        case "back", "none":
            self.init(action: .drop(.noReturn), scheme: "none", host: "none")
            return
        default:
            break
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              !scheme.isEmpty
        else {
            self.init(action: .drop(.unavailable), scheme: "none", host: "none")
            return
        }

        let action: Action
        let telemetryHost: String
        switch scheme {
        case "http", "https":
            let host = TonConnectReturnStrategy.normalizedHost(url.host)
            let hostKind = host.map(Self.hostKind) ?? .unavailable
            telemetryHost = host ?? "none"
            if host == nil {
                action = .drop(.unavailable)
            } else {
                action = hostKind == .public ? .openInAppURL(url) : .drop(.localAddress)
            }
        default:
            telemetryHost = "none"
            action = .open(url)
        }

        self.init(action: action, scheme: scheme, host: telemetryHost)
    }

    private init(action: Action, scheme: String, host: String) {
        self.action = action
        self.scheme = scheme
        self.host = host
    }

    private static func normalizedHost(_ host: String?) -> String? {
        guard let host = host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !host.isEmpty
        else {
            return nil
        }
        return host
    }

    private static func hostKind(_ host: String) -> HostKind {
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return .localhost
        }

        if let address = IPv4Address(host) {
            return address.isPrivateOrLocal ? .privateIP : .public
        }

        if let address = IPv6Address(host) {
            return address.isPrivateOrLocal ? .privateIP : .public
        }

        return .public
    }
}

private extension IPv4Address {
    var isPrivateOrLocal: Bool {
        let octets = rawValue
        guard octets.count == 4 else { return true }
        return octets[0] == 0
            || octets[0] == 10
            || octets[0] == 127
            || (octets[0] == 169 && octets[1] == 254)
            || (octets[0] == 172 && (16 ... 31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
    }
}

private extension IPv6Address {
    var isPrivateOrLocal: Bool {
        let bytes = rawValue
        guard bytes.count == 16 else { return true }
        let isUnspecified = bytes.allSatisfy { $0 == 0 }
        let isLoopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
        let isUniqueLocal = (bytes[0] & 0xFE) == 0xFC
        let isLinkLocal = bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80
        return isUnspecified || isLoopback || isUniqueLocal || isLinkLocal
    }
}
