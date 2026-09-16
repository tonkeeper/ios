import Foundation
import KeeperCore
import TKLocalize

enum PerpsTradingErrorText {
    static func message(for error: PerpsTradingError) -> String {
        switch error {
        case .offline:
            return TKLocales.Perps.Error.offline
        case .timeout:
            return TKLocales.Perps.Error.timeout
        case .rateLimited:
            return TKLocales.Perps.Error.rateLimited
        case .serverUnavailable:
            return TKLocales.Perps.Error.serverUnavailable
        case .serverRejected:
            return TKLocales.Perps.Error.serverRejected
        case .authExpired:
            return TKLocales.Perps.Error.authExpired
        case .credentialsRevoked:
            return TKLocales.Perps.Error.credentialsRevoked
        case .activationRequired:
            return TKLocales.Perps.Error.activationRequired
        case .activationCanceled:
            return ""
        case .regionUnavailable:
            return TKLocales.Perps.Error.regionUnavailable
        case .validation:
            return TKLocales.Perps.Error.generic
        case .nothingToChange:
            return ""
        case .insufficientBalance:
            return TKLocales.Perps.Error.insufficientBalance
        case .insufficientLiquidity:
            return TKLocales.Perps.Error.insufficientLiquidity
        case .positionNotFound:
            return TKLocales.Perps.Error.positionNotFound
        case .immediateLiquidationRisk:
            return TKLocales.Perps.AdjustMargin.reduceRisk
        case .protocolFailure:
            return TKLocales.Perps.Error.generic
        case .operationInProgress:
            return TKLocales.Perps.Error.submitUnknown
        case .stalePreparedTransaction:
            return TKLocales.Perps.Error.staleInputs
        case .submitUnknown:
            return TKLocales.Perps.Error.submitUnknown
        case .unknown:
            return TKLocales.Perps.Error.generic
        }
    }
}
