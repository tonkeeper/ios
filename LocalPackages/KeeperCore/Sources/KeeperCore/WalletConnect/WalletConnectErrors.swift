import Foundation

enum WalletConnectConfigurationError: Error, Equatable {
    case invalidRedirect
    case sdk(message: String)
}

public enum WalletConnectPairingError: Error, Equatable {
    case invalidURI(String)
    case missingPairingTopic(String)
    case sdk(message: String)
    case network(message: String)
}

extension WalletConnectPairingError {
    var isRetryableDeliveryFailure: Bool {
        switch self {
        case .network:
            return true
        case .invalidURI,
             .missingPairingTopic,
             .sdk:
            return false
        }
    }
}

public enum WalletConnectSessionApprovalError: Error, Equatable {
    case missingProposal(id: String)
    case unsupportedWalletKind
    case missingMultichainAddresses(walletId: String)
    case unsupportedRequiredChains([String])
    case unsupportedRequiredMethods([String])
    case invalidAccount(chain: WalletConnectChain)
    case rejectionFailed(WalletConnectSessionRejectionError)
    case storage(message: String)
    case sdk(message: String, retryable: Bool)
}

public enum WalletConnectSessionRejectionError: Error, Equatable {
    case missingProposal(id: String)
    case sdk(message: String, retryable: Bool)
}

public enum WalletConnectResponseError: Error, Equatable {
    case missingRequest(id: String)
    case requestExpired(id: String)
    case missingSession(topic: String)
    case storage(message: String)
    case sdk(message: String, retryable: Bool)
}

public enum WalletConnectRequestRejectionReason: Sendable, Equatable {
    case userRejected
    case invalidParams
    case unsupportedChain
    case notImplemented
}

public extension WalletConnectResponseError {
    var isRetryableDeliveryFailure: Bool {
        switch self {
        case let .sdk(_, retryable):
            return retryable
        case .missingRequest,
             .requestExpired,
             .missingSession,
             .storage:
            return false
        }
    }

    var isMissingSession: Bool {
        if case .missingSession = self {
            return true
        }
        return false
    }
}

public extension WalletConnectSessionApprovalError {
    var isRetryableDeliveryFailure: Bool {
        switch self {
        case let .sdk(_, retryable):
            return retryable
        case let .rejectionFailed(error):
            return error.isRetryableDeliveryFailure
        case .missingProposal,
             .unsupportedWalletKind,
             .missingMultichainAddresses,
             .unsupportedRequiredChains,
             .unsupportedRequiredMethods,
             .invalidAccount,
             .storage:
            return false
        }
    }
}

public extension WalletConnectSessionRejectionError {
    var isRetryableDeliveryFailure: Bool {
        switch self {
        case let .sdk(_, retryable):
            return retryable
        case .missingProposal:
            return false
        }
    }
}

extension WalletConnectResponseError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .missingRequest(id):
            return "WalletConnect request \(id) is no longer pending"
        case .requestExpired:
            return "Request expired"
        case let .missingSession(topic):
            return "WalletConnect session \(topic) is no longer active"
        case let .storage(message):
            return "Failed to save WalletConnect session changes: \(message)"
        case let .sdk(message, retryable):
            if retryable {
                return "Failed to send WalletConnect response. Check your connection and try again."
            }
            return message
        }
    }
}

extension WalletConnectPairingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURI:
            return "WalletConnect link is invalid"
        case .missingPairingTopic:
            return "WalletConnect link has no pairing topic"
        case let .sdk(message):
            return message
        case .network:
            return "Check your connection and try again."
        }
    }
}

extension WalletConnectSessionApprovalError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingProposal:
            return "WalletConnect proposal is no longer available"
        case .unsupportedWalletKind:
            return "Wallet type is not supported for WalletConnect"
        case .missingMultichainAddresses:
            return "Selected wallet does not have required multichain addresses"
        case .unsupportedRequiredChains:
            return "WalletConnect network is not supported"
        case .unsupportedRequiredMethods:
            return "WalletConnect method is not supported"
        case .invalidAccount:
            return "WalletConnect account is invalid"
        case let .rejectionFailed(error):
            return error.errorDescription
        case let .storage(message):
            return "Failed to save WalletConnect session changes: \(message)"
        case let .sdk(message, retryable):
            if retryable {
                return "Failed to send WalletConnect response. Check your connection and try again."
            }
            return message
        }
    }
}

extension WalletConnectSessionRejectionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .missingProposal(id):
            return "WalletConnect proposal \(id) is no longer pending"
        case let .sdk(message, retryable):
            if retryable {
                return "Failed to send WalletConnect response. Check your connection and try again."
            }
            return message
        }
    }
}

public enum WalletConnectSigningError: Error, Equatable {
    case canceled
    case unsupportedWalletKind
    case missingMultichainAddress(chain: WalletConnectChain, walletId: String)
    case senderAddressMismatch(expected: String, actual: String)
    case missingRecipient
    case missingPasscode
    case mnemonic(reason: String)
    case invalidPayload(reason: String)
    case invalidTransaction(reason: String)
    case failedToEstimateNonce(reason: String)
    case failedToCalculateFee(reason: String)
    case failedToSign(reason: String)
    case failedToSend(reason: String)
    case notImplemented(reason: String)
}

public extension WalletConnectSigningError {
    var walletConnectRequestRejectionReason: WalletConnectRequestRejectionReason {
        switch self {
        case .invalidPayload,
             .invalidTransaction,
             .senderAddressMismatch,
             .missingRecipient:
            return .invalidParams
        case .canceled,
             .unsupportedWalletKind,
             .missingMultichainAddress,
             .missingPasscode,
             .mnemonic,
             .failedToEstimateNonce,
             .failedToCalculateFee,
             .failedToSign,
             .failedToSend:
            return .userRejected
        case .notImplemented:
            return .notImplemented
        }
    }
}

extension WalletConnectSigningError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .canceled:
            return "WalletConnect request was cancelled"
        case .unsupportedWalletKind:
            return "Wallet type is not supported for WalletConnect"
        case let .missingMultichainAddress(chain, walletId):
            return "Wallet \(walletId) has no address for \(chain.caip2)"
        case let .senderAddressMismatch(expected, actual):
            return "Sender address mismatch: expected \(expected), got \(actual)"
        case .missingRecipient:
            return "WalletConnect transaction recipient is missing"
        case .missingPasscode:
            return "Passcode is missing"
        case let .mnemonic(reason),
             let .invalidPayload(reason),
             let .invalidTransaction(reason),
             let .failedToEstimateNonce(reason),
             let .failedToCalculateFee(reason),
             let .failedToSign(reason),
             let .failedToSend(reason),
             let .notImplemented(reason):
            return reason
        }
    }
}
