import Foundation
import PerpsModels
import TKLocalize

public enum PerpsTradingErrorText {
    /// Errors a screen deliberately says nothing about (a cancelled passcode, a
    /// no-op change) map to an empty message, so every caller that must show
    /// something needs a fallback of its own.
    public static func message(for error: PerpsTradingError, fallback: String) -> String {
        let message = message(for: error)
        return message.isEmpty ? fallback : message
    }

    public static func message(for error: PerpsTradingError) -> String {
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
        case .tradingUnavailable:
            return TKLocales.Perps.Error.tradingUnavailable
        case .validation:
            return TKLocales.Perps.Error.generic
        case .invalidAutoClose(.takeProfit):
            return TKLocales.Perps.Confirm.takeProfitNeedsUpdateTitle
        case .invalidAutoClose(.stopLoss):
            return TKLocales.Perps.Confirm.stopLossNeedsUpdateTitle
        case .invalidAutoClose(nil):
            return TKLocales.Perps.Error.autoCloseInvalid
        case .invalidAmount:
            return TKLocales.Perps.Error.invalidAmount
        case .conflictingPosition:
            return TKLocales.Perps.Error.conflictingPosition
        case .exceedsPosition:
            return TKLocales.Perps.Error.exceedsPosition
        case .nothingToChange:
            return ""
        case .insufficientBalance:
            return TKLocales.Perps.Error.insufficientBalance
        case .insufficientLiquidity:
            return TKLocales.Perps.Error.insufficientLiquidity
        case .slippageExceeded:
            return TKLocales.Perps.Confirm.orderNotPlacedTitle
        case .positionNotFound:
            return TKLocales.Perps.Error.positionNotFound
        case .orderNotFound:
            return TKLocales.Perps.Error.orderNotFound
        case .immediateLiquidationRisk:
            return TKLocales.Perps.AdjustMargin.reduceRisk
        case .protocolFailure:
            return TKLocales.Perps.Error.generic
        case .operationInProgress:
            return TKLocales.Perps.Error.operationInProgress
        case .stalePreparedTransaction:
            return TKLocales.Perps.Error.staleInputs
        case .deviceClockSkew:
            return TKLocales.Perps.Error.wrongDeviceTime
        case .submitUnknown:
            return TKLocales.Perps.Error.submitUnknown
        case .unknown:
            return TKLocales.Perps.Error.generic
        }
    }
}
