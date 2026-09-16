import BigInt
import ChainKit

/// Resolves the network fee of a swap transaction through the ChainKit mediator.
/// Used when the aggregator payload carries no fee of its own (the payload fee always
/// wins); also converts ChainKit fee values into `BigUInt` for display and aggregation.
/// The default fee is the chain's own flat estimate, priced without emulating anything.
struct SwapFeeResolver {
    func resolveFee<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction
    ) async throws(MultichainTransactionEmulationFailure) -> Fee {
        let feeResult: ChainRes<Fee>
        do {
            feeResult = try await mediator.fee.calculateFee(transaction: transaction)
        } catch {
            throw .internal(
                reason: "chain kit failed to calculate fee due to error: \(error.logDescription)"
            )
        }
        guard let fee = feeResult.getOrNull() else {
            let error = feeResult.error.map(\.logValue) ?? "unknown"
            throw .chainError(
                kind: ChainKitErrorKindClassifier.kind(chainError: feeResult.error),
                reason: "chain kit failed to calculate fee due to error: \(error)"
            )
        }
        return fee
    }

    func resolveDefaultFee<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        transaction: any ChainKit.Transaction
    ) async throws(MultichainTransactionEmulationFailure) -> Fee {
        let feeResult: ChainRes<Fee>
        do {
            feeResult = try await mediator.fee.getDefaultFee(transaction: transaction)
        } catch {
            throw .internal(
                reason: "chain kit failed to read default fee due to error: \(error.logDescription)"
            )
        }
        guard let fee = feeResult.getOrNull() else {
            let error = feeResult.error.map(\.logValue) ?? "unknown"
            throw .chainError(
                kind: ChainKitErrorKindClassifier.kind(chainError: feeResult.error),
                reason: "chain kit failed to read default fee due to error: \(error)"
            )
        }
        return fee
    }

    func amount(of fee: Fee) throws(MultichainTransactionEmulationFailure) -> BigUInt {
        guard let amount = BigUInt(fee.amount.description) else {
            throw .internal(
                reason: "fee amount value is not a number: \(fee.amount.description)"
            )
        }
        return amount
    }

    func combinedFee(_ fees: [any Fee]) -> FeeValue {
        let amount = fees.reduce(BignumBigInteger.Companion.shared.ZERO) { partialResult, fee in
            partialResult.add(other: fee.amount)
        }
        return FeeValue(amount: amount)
    }
}
