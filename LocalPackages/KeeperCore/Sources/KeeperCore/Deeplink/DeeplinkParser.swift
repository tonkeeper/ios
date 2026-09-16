import BigInt
import Foundation
import TonSwift

public enum DeeplinkParserError: Swift.Error, LocalizedError, Equatable {
    public enum UnsupportedDeeplinkCode: Int {
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
    case ignoredWalletConnectWakeUp

    public var errorDescription: String? {
        switch self {
        case let .unsupportedDeeplink(code, string):
            "Unsupported deeplink(code: \(code.rawValue): \(string ?? ""))"
        case .invalidParameters:
            "Invalid parameters"
        case let .unknownQueryItem(name):
            "Unknown parameter \(name)"
        case .ignoredWalletConnectWakeUp:
            "WalletConnect wake-up deeplink ignored"
        }
    }

    public var isSilent: Bool {
        switch self {
        case .ignoredWalletConnectWakeUp:
            return true
        case .unsupportedDeeplink,
             .invalidParameters,
             .unknownQueryItem:
            return false
        }
    }
}

public struct DeeplinkParser: Sendable {
    private let tonkeeperParser: TonkeeperDeeplinkParser
    private let ethereumTransferLinkParser = EthereumTransferLinkParser()
    private let walletConnectDeeplinkValidator: WalletConnectDeeplinkValidator

    init(
        walletConnectDeeplinkValidator: WalletConnectDeeplinkValidator
    ) {
        self.tonkeeperParser = TonkeeperDeeplinkParser(
            walletConnectDeeplinkValidator: walletConnectDeeplinkValidator
        )
        self.walletConnectDeeplinkValidator = walletConnectDeeplinkValidator
    }

    public func parse(
        string: String?,
        source: DappConnectionSource? = nil
    ) throws(DeeplinkParserError) -> Deeplink {
        guard let string,
              !string.isEmpty
        else {
            throw .unsupportedDeeplink(code: .nilValue, string: string)
        }

        if let walletConnectDeeplink = parseWalletConnectDeeplink(
            string: string,
            source: source
        ) {
            return walletConnectDeeplink
        }

        if isWalletConnectWakeUpDeeplink(string: string) {
            throw .ignoredWalletConnectWakeUp
        }

        if isWalletConnectDeeplinkContainer(string: string) {
            throw .unsupportedDeeplink(code: .notSupportedPath, string: string)
        }

        if let tonconnectDeeplink = parseTonconnectDeeplink(
            string: string,
            source: source ?? .deeplink
        ) {
            return tonconnectDeeplink
        }

        if let evmTransfer = ethereumTransferLinkParser.parse(string: string) {
            return .transfer(.evmSendTransfer(evmTransfer))
        }

        let deeplinkPrefixes = [
            "ton://",
            "tonkeeper://",
            "tonkeeper-mob://",
            "https://app.tonkeeper.com/",
            "https://app.tonkeeper.org/",
            "https://tonhub.com/",
            "tonkeeper-mob://",
            "tonkeeper-tc-mob://",
        ]

        guard let prefix = deeplinkPrefixes.first(where: { string.hasPrefix($0) }) else {
            throw .unsupportedDeeplink(code: .invalidPrefix, string: string)
        }

        let prefixIndex = string.index(string.startIndex, offsetBy: prefix.count)
        let unprefixedString = String(string[prefixIndex...])

        return try tonkeeperParser.parse(
            string: unprefixedString,
            tonConnectSource: source ?? .deeplink
        )
    }

    private func parseTonconnectDeeplink(
        string: String,
        source: DappConnectionSource
    ) -> Deeplink? {
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
            return try .tonconnect(
                tonkeeperParser.parseTonconnect(
                    url: url,
                    source: source
                )
            )
        } catch {
            return nil
        }
    }

    private func parseWalletConnectDeeplink(
        string: String,
        source sourceOverride: DappConnectionSource?
    ) -> Deeplink? {
        if walletConnectDeeplinkValidator.isPairingURI(string) {
            return .walletConnect(
                WalletConnectDeeplink(
                    uri: WalletConnectURIParser.normalized(string),
                    source: sourceOverride ?? .deeplink
                )
            )
        }

        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmedString) else {
            return nil
        }

        let source = walletConnectSource(from: components)

        guard let source,
              let uri = WalletConnectURIParser.wrappedURI(from: trimmedString)
              .map(WalletConnectURIParser.normalized),
              walletConnectDeeplinkValidator.isPairingURI(uri)
        else {
            return nil
        }

        return .walletConnect(
            WalletConnectDeeplink(
                uri: uri,
                source: sourceOverride ?? source
            )
        )
    }

    private func isWalletConnectDeeplinkContainer(string: String) -> Bool {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmedString) else {
            return false
        }
        return walletConnectSource(from: components) != nil
    }

    private func isWalletConnectWakeUpDeeplink(string: String) -> Bool {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if WalletConnectURIParser.wakeUpTopic(from: trimmedString) != nil {
            return true
        }
        if let uri = WalletConnectURIParser.wrappedURI(from: trimmedString) {
            return WalletConnectURIParser.wakeUpTopic(from: uri) != nil
        }
        return isWalletConnectDeeplinkContainer(string: trimmedString)
    }

    private func walletConnectSource(from components: URLComponents) -> DappConnectionSource? {
        switch (
            components.scheme?.lowercased(),
            components.host?.lowercased(),
            components.path.lowercased()
        ) {
        case ("ton", "wc", _),
             ("tonkeeper", "wc", _),
             ("tonkeeper-mob", "wc", _):
            return .deeplink
        case ("https", "app.tonkeeper.com", "/wc"),
             ("https", "app.tonkeeper.org", "/wc"),
             ("https", "tonhub.com", "/wc"):
            return .deeplink
        default:
            return nil
        }
    }
}
