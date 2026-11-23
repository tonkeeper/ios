import Foundation
import OpenAPIRuntime

public extension BatteryPurchaseError {
    static func isNetworkError(_ error: Error) -> Bool {
        switch error {
        case let error as URLError:
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost,
                 .dataNotAllowed, .internationalRoamingOff, .secureConnectionFailed,
                 .cannotLoadFromNetwork, .resourceUnavailable, .callIsActive:
                return true
            default:
                return false
            }
        case let error as ClientError:
            return isNetworkError(error.underlyingError)
        case let BatteryAPI.ApiError.unknown(underlying?):
            return isNetworkError(underlying)
        case let BatteryAuthorizationError.deviceSessionFailure(underlying):
            return isNetworkError(underlying)
        case let MultichainTransactionFailure.failedToSign(kind, _),
             let MultichainTransactionFailure.failedToEstimateNonce(kind, _),
             let MultichainTransactionFailure.emulationFailure(.chainError(kind, _)):
            return kind == .networkError
        case DeviceAuthError.connectionError:
            return true
        case MultichainClientAPIError.connectionError:
            return true
        default:
            return false
        }
    }
}
