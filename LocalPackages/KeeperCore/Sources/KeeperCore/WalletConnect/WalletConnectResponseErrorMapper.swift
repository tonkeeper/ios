import Foundation

enum WalletConnectResponseErrorMapper {
    static func map(
        _ error: Error,
        requestId _: String?,
        topic _: String?
    ) -> WalletConnectResponseError {
        let details = WalletConnectSDKErrorDetails(error)

        if details.isRetryableDeliveryFailure {
            return .sdk(message: details.localized, retryable: true)
        }

        return .sdk(message: details.localized, retryable: false)
    }
}

enum WalletConnectPairingErrorMapper {
    static func map(_ error: Error) -> WalletConnectPairingError {
        let details = WalletConnectSDKErrorDetails(error)
        if details.isRetryableDeliveryFailure {
            return .network(message: details.localized)
        }
        return .sdk(message: details.localized)
    }
}

enum WalletConnectSessionProposalErrorMapper {
    static func mapApproval(
        _ error: Error,
        proposalId _: String
    ) -> WalletConnectSessionApprovalError {
        let details = WalletConnectSDKErrorDetails(error)
        return .sdk(
            message: details.localized,
            retryable: details.isRetryableDeliveryFailure
        )
    }

    static func mapRejection(
        _ error: Error,
        proposalId _: String
    ) -> WalletConnectSessionRejectionError {
        let details = WalletConnectSDKErrorDetails(error)
        return .sdk(
            message: details.localized,
            retryable: details.isRetryableDeliveryFailure
        )
    }
}

struct WalletConnectSDKErrorDetails {
    let localized: String
    let nsError: NSError

    init(_ error: Error) {
        let localized = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        self.localized = localized
        self.nsError = error as NSError
    }

    var isRetryableDeliveryFailure: Bool {
        isRetryableFoundationNetworkFailure || isRetryableRelayFailure
    }
}

private extension WalletConnectSDKErrorDetails {
    var isRetryableRelayFailure: Bool {
        nsErrorChain.contains { error in
            error.localizedDescription == Self.relayRequestTimeoutMessage
        }
    }

    var isRetryableFoundationNetworkFailure: Bool {
        nsErrorChain.contains { error in
            switch error.domain {
            case NSURLErrorDomain:
                return Self.retryableURLFailureCodes.contains(error.code)
            case NSPOSIXErrorDomain:
                return Self.retryablePOSIXFailureCodes.contains(error.code)
            default:
                return false
            }
        }
    }

    var nsErrorChain: [NSError] {
        var errors = [NSError]()
        var current: NSError? = nsError
        for _ in 0 ..< 5 {
            guard let error = current else {
                break
            }
            errors.append(error)
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return errors
    }

    static var retryableURLFailureCodes: Set<Int> {
        [
            URLError.Code.timedOut.rawValue,
            URLError.Code.cannotFindHost.rawValue,
            URLError.Code.cannotConnectToHost.rawValue,
            URLError.Code.networkConnectionLost.rawValue,
            URLError.Code.notConnectedToInternet.rawValue,
            URLError.Code.dnsLookupFailed.rawValue,
        ]
    }

    static var retryablePOSIXFailureCodes: Set<Int> {
        Set([
            POSIXErrorCode.ETIMEDOUT,
            POSIXErrorCode.ENETDOWN,
            POSIXErrorCode.ENETUNREACH,
            POSIXErrorCode.ECONNRESET,
            POSIXErrorCode.ECONNREFUSED,
            POSIXErrorCode.EHOSTDOWN,
            POSIXErrorCode.EHOSTUNREACH,
        ].map { Int($0.rawValue) })
    }

    static let relayRequestTimeoutMessage = "Relay request timeout"
}
