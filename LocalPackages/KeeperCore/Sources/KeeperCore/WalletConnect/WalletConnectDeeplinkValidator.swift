public protocol WalletConnectDeeplinkValidator: Sendable {
    func isPairingURI(_ uri: String) -> Bool
}

// MARK: -

struct WalletConnectDeeplinkValidatorImplementation: WalletConnectDeeplinkValidator {
    func isPairingURI(_ uri: String) -> Bool {
        WalletConnectURIParser.isRawPairingURI(uri)
    }
}
