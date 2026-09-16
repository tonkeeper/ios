import TKLogging

extension WalletConnectConfigurationError: LoggableError {
    public var logDescription: String {
        switch self {
        case .invalidRedirect:
            return walletConnectLogDescription(type: "WalletConnectConfigurationError", caseName: "invalidRedirect")
        case .sdk:
            return walletConnectLogDescription(type: "WalletConnectConfigurationError", caseName: "sdk")
        }
    }
}

extension WalletConnectPairingError: LoggableError {
    public var logDescription: String {
        switch self {
        case .invalidURI:
            return walletConnectLogDescription(type: "WalletConnectPairingError", caseName: "invalidURI")
        case .missingPairingTopic:
            return walletConnectLogDescription(type: "WalletConnectPairingError", caseName: "missingPairingTopic")
        case .sdk:
            return walletConnectLogDescription(type: "WalletConnectPairingError", caseName: "sdk")
        case .network:
            return walletConnectLogDescription(type: "WalletConnectPairingError", caseName: "network")
        }
    }
}

extension WalletConnectSessionApprovalError: LoggableError {
    public var logDescription: String {
        switch self {
        case .missingProposal:
            return walletConnectLogDescription(type: "WalletConnectSessionApprovalError", caseName: "missingProposal")
        case .unsupportedWalletKind:
            return walletConnectLogDescription(type: "WalletConnectSessionApprovalError", caseName: "unsupportedWalletKind")
        case .missingMultichainAddresses:
            return walletConnectLogDescription(
                type: "WalletConnectSessionApprovalError",
                caseName: "missingMultichainAddresses"
            )
        case let .unsupportedRequiredChains(chains):
            return walletConnectLogDescription(
                type: "WalletConnectSessionApprovalError",
                caseName: "unsupportedRequiredChains",
                values: [("chains", chains.sorted().joined(separator: ","))]
            )
        case let .unsupportedRequiredMethods(methods):
            return walletConnectLogDescription(
                type: "WalletConnectSessionApprovalError",
                caseName: "unsupportedRequiredMethods",
                values: [("methods", methods.sorted().joined(separator: ","))]
            )
        case let .invalidAccount(chain):
            return walletConnectLogDescription(
                type: "WalletConnectSessionApprovalError",
                caseName: "invalidAccount",
                values: [("chain", chain.caip2)]
            )
        case let .rejectionFailed(error):
            return walletConnectLogDescription(
                type: "WalletConnectSessionApprovalError",
                caseName: "rejectionFailed",
                values: [("underlying", error.logDescription)]
            )
        case .storage:
            return walletConnectLogDescription(type: "WalletConnectSessionApprovalError", caseName: "storage")
        case let .sdk(_, retryable):
            return walletConnectLogDescription(
                type: "WalletConnectSessionApprovalError",
                caseName: "sdk",
                values: [("retryable", "\(retryable)")]
            )
        }
    }
}

extension WalletConnectSessionRejectionError: LoggableError {
    public var logDescription: String {
        switch self {
        case .missingProposal:
            return walletConnectLogDescription(type: "WalletConnectSessionRejectionError", caseName: "missingProposal")
        case let .sdk(_, retryable):
            return walletConnectLogDescription(
                type: "WalletConnectSessionRejectionError",
                caseName: "sdk",
                values: [("retryable", "\(retryable)")]
            )
        }
    }
}

extension WalletConnectResponseError: LoggableError {
    public var logDescription: String {
        switch self {
        case .missingRequest:
            return walletConnectLogDescription(type: "WalletConnectResponseError", caseName: "missingRequest")
        case .requestExpired:
            return walletConnectLogDescription(type: "WalletConnectResponseError", caseName: "requestExpired")
        case .missingSession:
            return walletConnectLogDescription(type: "WalletConnectResponseError", caseName: "missingSession")
        case .storage:
            return walletConnectLogDescription(type: "WalletConnectResponseError", caseName: "storage")
        case let .sdk(_, retryable):
            return walletConnectLogDescription(
                type: "WalletConnectResponseError",
                caseName: "sdk",
                values: [("retryable", "\(retryable)")]
            )
        }
    }
}

extension WalletConnectSigningError: LoggableError {
    public var logDescription: String {
        switch self {
        case .canceled:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "canceled")
        case .unsupportedWalletKind:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "unsupportedWalletKind")
        case let .missingMultichainAddress(chain, _):
            return walletConnectLogDescription(
                type: "WalletConnectSigningError",
                caseName: "missingMultichainAddress",
                values: [("chain", chain.caip2)]
            )
        case .senderAddressMismatch:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "senderAddressMismatch")
        case .missingRecipient:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "missingRecipient")
        case .missingPasscode:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "missingPasscode")
        case .mnemonic:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "mnemonic")
        case .invalidPayload:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "invalidPayload")
        case .invalidTransaction:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "invalidTransaction")
        case .failedToEstimateNonce:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "failedToEstimateNonce")
        case .failedToCalculateFee:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "failedToCalculateFee")
        case .failedToSign:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "failedToSign")
        case .failedToSend:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "failedToSend")
        case .notImplemented:
            return walletConnectLogDescription(type: "WalletConnectSigningError", caseName: "notImplemented")
        }
    }
}

extension WalletConnectRequestParsingError: LoggableError {
    public var logDescription: String {
        switch self {
        case let .unsupportedMethod(method):
            return walletConnectLogDescription(
                type: "WalletConnectRequestParsingError",
                caseName: "unsupportedMethod",
                values: [("method", method)]
            )
        case let .unsupportedChain(chain):
            return walletConnectLogDescription(
                type: "WalletConnectRequestParsingError",
                caseName: "unsupportedChain",
                values: [("chain", chain)]
            )
        case let .invalidParams(method, _):
            return walletConnectLogDescription(
                type: "WalletConnectRequestParsingError",
                caseName: "invalidParams",
                values: [("method", method.rawValue)]
            )
        case let .chainMismatch(expected, actual):
            return walletConnectLogDescription(
                type: "WalletConnectRequestParsingError",
                caseName: "chainMismatch",
                values: [("expectedChain", expected.caip2), ("actualChain", actual)]
            )
        }
    }
}

extension WalletConnectPairingSourceStoreError: LoggableError {
    var logDescription: String {
        walletConnectLogDescription(type: "WalletConnectPairingSourceStoreError", caseName: "saveFailed")
    }
}

extension WalletConnectSessionStoreError: LoggableError {
    var logDescription: String {
        walletConnectLogDescription(type: "WalletConnectSessionStoreError", caseName: "saveFailed")
    }
}

private func walletConnectLogDescription(
    type: String,
    caseName: String,
    values: [(String, String)] = []
) -> String {
    (["type=\(type)", "case=\(caseName)"] + values.map { "\($0.0)=\($0.1)" })
        .joined(separator: ", ")
}
