import Foundation
import PerpsModels

public extension PerpsPendingDeposit {
    /// Only an aggregator fill has the converting step: a direct deposit and one through Lighter's
    /// fun.xyz bridge go from sending straight to adding, so a converting reported for them shows as adding.
    var skipsConversion: Bool {
        route == .directGateway || executionId?.hasPrefix("funxyz_") == true
    }
}

extension PerpsPendingFundingOperation {
    var depositStatus: PerpsDepositStatus? {
        guard let deposit, !isBeforeSideEffect else { return nil }
        let state: PerpsDepositStatus.State
        switch deposit.stage {
        case .credited: state = .completed
        case .failed: state = .failed
        case .refunded: state = .refunded
        case .unconfirmed: state = .unconfirmed
        default:
            guard deposit.stage.isInFlight else { return nil }
            state = .pending
        }
        func amount(_ units: String?, decimals: Int) -> String? {
            guard let units, let value = try? PerpsFundingAmount.integerUnits(units) else { return nil }
            return PerpsFundingAmount.declaredAmount(units: value, decimals: decimals)
        }
        guard let sourceAmount = amount(deposit.sourceAmountUnits, decimals: deposit.sourceAsset.decimals) else { return nil }
        let skipsConversion = deposit.skipsConversion
        return PerpsDepositStatus(
            id: operationId,
            createdAt: Date(timeIntervalSince1970: Double(createdAtMillis) / 1000),
            sourceAmount: sourceAmount,
            sourceSymbol: deposit.sourceAsset.symbol,
            sourceNetwork: deposit.sourceAsset.assetId.split(separator: "/").first.map(String.init) ?? "",
            expectedAmount: amount(deposit.gatewayAmountUnits ?? deposit.minimumTargetAmountUnits, decimals: deposit.targetAsset.decimals),
            creditedAmount: deposit.creditedAmount,
            estimatedDurationSeconds: deposit.estimatedDurationSeconds,
            state: state,
            step: skipsConversion && deposit.pendingStep == .converting ? .adding : deposit.pendingStep,
            skipsConversion: skipsConversion
        )
    }
}
