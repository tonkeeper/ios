import Foundation

public enum DappConnectionSource: String, Codable, Sendable, Equatable {
    case qr
    case browser
    case dapp
    case deeplink
}

public struct DappConnectionExtraInfo: Sendable, Equatable {
    public let source: DappConnectionSource
    public let createdAt: Date

    public init(
        source: DappConnectionSource,
        createdAt: Date
    ) {
        self.source = source
        self.createdAt = createdAt
    }

    public init?(
        source: DappConnectionSource?,
        createdAt: Date?
    ) {
        guard let source, let createdAt else {
            return nil
        }
        self.init(source: source, createdAt: createdAt)
    }
}

public enum DappConnectionSourceState: Sendable, Equatable {
    case known(DappConnectionExtraInfo)
    case unknown

    public init(
        source: DappConnectionSource?,
        createdAt: Date?
    ) {
        guard let extraInfo = DappConnectionExtraInfo(
            source: source,
            createdAt: createdAt
        ) else {
            self = .unknown
            return
        }
        self = .known(extraInfo)
    }

    public var extraInfo: DappConnectionExtraInfo? {
        switch self {
        case let .known(extraInfo):
            return extraInfo
        case .unknown:
            return nil
        }
    }

    public var isUnknown: Bool {
        switch self {
        case .known:
            return false
        case .unknown:
            return true
        }
    }
}

public extension KeyedDecodingContainer {
    func decodeDappConnectionSourceIfPresent(forKey key: Key) -> DappConnectionSource? {
        guard let rawValue = try? decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        return DappConnectionSource(rawValue: rawValue)
    }
}
