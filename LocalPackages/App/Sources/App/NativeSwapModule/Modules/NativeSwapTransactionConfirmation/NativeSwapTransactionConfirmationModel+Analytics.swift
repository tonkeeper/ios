import Foundation
import KeeperCore
import TKCore

extension NativeSwapTransactionConfirmationModel {
    var fromAmountValue: Double {
        NSDecimalNumber.fromBigUInt(value: fromAmount, decimals: fromToken.fractionDigits).doubleValue
    }

    var toAmountValue: Double {
        NSDecimalNumber.fromBigUInt(value: toAmount, decimals: toToken.fractionDigits).doubleValue
    }

    func confirmEvent(feePaidIn: String) -> AnalyticsEventLegacy {
        .NativeSwap.confirm(
            from: fromToken.analyticsSymbol,
            to: toToken.analyticsSymbol,
            feeProvider: feePaidIn,
            providerName: confirmation.resolverName,
            amount: fromAmountValue
        )
    }

    func failedEvent(feePaidIn: String, error: any AnalyticsError) -> AnalyticsEventLegacy {
        .NativeSwap.failed(
            from: fromToken.analyticsSymbol,
            to: toToken.analyticsSymbol,
            feeProvider: feePaidIn,
            providerName: confirmation.resolverName,
            amount: fromAmountValue,
            errorCode: error.code,
            errorMessage: error.message
        )
    }

    func successEvent(feePaidIn: String) -> AnalyticsEventLegacy {
        .NativeSwap.success(
            from: fromToken.analyticsSymbol,
            to: toToken.analyticsSymbol,
            feeProvider: feePaidIn,
            providerName: confirmation.resolverName,
            amount: fromAmountValue
        )
    }
}
