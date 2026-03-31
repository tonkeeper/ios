import BigInt
import Foundation
import TonSwift

enum DeeplinkParserError: Swift.Error, LocalizedError {
    enum UnsupportedDeeplinkCode: Int {
        case nilValue
        case notUrl
        case invalidPrefix
        case firstClean
        case firstPathComponent
        case notSupportedPath
    }

    case unsupportedDeeplink(code: UnsupportedDeeplinkCode, string: String?)
    case invalidParameters
    case unknownQueryItem(name: String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedDeeplink(code, string):
            "Unsupported deeplink(code: \(code.rawValue): \(string ?? ""))"
        case .invalidParameters:
            "Invalid parameters"
        case let .unknownQueryItem(name):
            "Unknown parameter \(name)"
        }
    }
}

public struct DeeplinkParser {
    private let tonkeeperParser = TonkeeperDeeplinkParser()

    public init() {}

    public func parse(string: String?) throws -> Deeplink {
        guard let string,
              !string.isEmpty
        else {
            throw DeeplinkParserError.unsupportedDeeplink(code: .nilValue, string: string)
        }

        if let tonconnectDeeplink = parseTonconnectDeeplink(string: string) {
            return tonconnectDeeplink
        }

        let deeplinkPrefixes = [
            "ton://",
            "tonkeeper://",
            "tonkeeper-mob://",
            "https://app.tonkeeper.com/",
            "https://tonhub.com/",
            "tonkeeper-mob://",
            "tonkeeper-tc-mob://",
        ]

        guard let prefix = deeplinkPrefixes.first(where: { string.hasPrefix($0) }) else {
            throw DeeplinkParserError.unsupportedDeeplink(code: .invalidPrefix, string: string)
        }

        let prefixIndex = string.index(string.startIndex, offsetBy: prefix.count)
        let unprefixedString = String(string[prefixIndex...])

        return try tonkeeperParser.parse(string: unprefixedString)
    }

    private func parseTonconnectDeeplink(string: String) -> Deeplink? {
        let tonconnectDeeplinkPrefixes = [
            "tc://",
            "tonkeeper-tc://",
            "tonkeeper-tc-mob://",
        ]

        guard let prefix = tonconnectDeeplinkPrefixes.first(where: { string.hasPrefix($0) }) else {
            return nil
        }

        let prefixIndex = string.index(string.startIndex, offsetBy: prefix.count)
        let unprefixedString = String(string[prefixIndex...])
        guard let url = URL(string: unprefixedString) else { return nil }

        do {
            return try .tonconnect(tonkeeperParser.parseTonconnect(url: url))
        } catch {
            return nil
        }
    }
}
