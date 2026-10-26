import BigInt
import ChainKit

/// Resolves the network fee of a swap transaction through the ChainKit mediator.
/// Used when the aggregator payload carries no fee of its own (the payload fee always
/// wins); also converts ChainKit fee values into `BigUInt` for display and aggregation.
/// The default fee is the chain's own flat estimate, priced without emulating anything.
struct SwapFeeResolver {
    /// The largest message is priced once and charged for every message: pricing each one ran into
    /// the node's rate limit.
    func resolveFee<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        batch: [TransactionSwap]
    ) async throws(MultichainTransactionEmulationFailure) -> Fee {
        guard let message = Self.pricedMessage(of: batch) else {
            throw .internal(reason: "swap has no message to price")
        }
        return try await Self.batchFee(
            resolveFee(mediator: mediator, transaction: message),
            messageCount: batch.count
        )
    }

    func resolveDefaultFee<I, O>(
        mediator: ChainMediatorWrapper<I, O>,
        batch: [TransactionSwap]
    ) async throws(MultichainTransactionEmulationFailure) -> Fee {
        guard let message = Self.pricedMessage(of: batch) else {
            throw .internal(reason: "swap has no message to price")
        }
        return try await Self.batchFee(
            resolveDefaultFee(mediator: mediator, transaction: message),
            messageCount: batch.count
        )
    }

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

    func combinedFee(_ fees: [any Fee], asset: any ChainKit.Asset) -> FeeValue {
        let amount = fees.reduce(BignumBigInteger.Companion.shared.ZERO) { partialResult, fee in
            partialResult.add(other: fee.amount)
        }
        return FeeValue(asset: asset, amount: amount)
    }

    /// W5 silently drops a message the balance cannot cover and still charges the fee, so the coin
    /// the messages carry is reserved together with the fees.
    func reservedFee(_ fees: [any Fee], attachedEnergy: BignumBigInteger, asset: any ChainKit.Asset) -> FeeValue {
        FeeValue(asset: asset, amount: combinedFee(fees, asset: asset).amount.add(other: attachedEnergy))
    }

    static func pricedMessage(of batch: [TransactionSwap]) -> TransactionSwap? {
        batch.max { ($0.data ?? "").count < ($1.data ?? "").count }?.asEnergyMessage
    }

    static func batchFee(_ fee: Fee, messageCount: Int) -> Fee {
        guard messageCount > 1 else {
            return fee
        }
        return FeeValue(
            asset: fee.asset,
            amount: fee.amount.multiply(other: BignumBigInteger.Companion.shared.fromInt(int: Int32(messageCount)))
        )
    }
}
