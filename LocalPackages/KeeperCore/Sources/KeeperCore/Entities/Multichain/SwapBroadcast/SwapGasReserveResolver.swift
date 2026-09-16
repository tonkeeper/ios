import BigInt
import ChainKit

/// Runs ChainKit's gas-reserve math for the main swap transaction. The policy comes
/// from the payload's calldata: `ShrinkToFit` where the amount may move, `DrainOrError`
/// where it is baked into the calldata and must reach the chain untouched. A balance
/// that cannot cover the fee surfaces as an insufficient-balance failure; any amount
/// returned by ChainKit is handled by the transaction adjuster.
struct SwapGasReserveResolver {
    let client: CryptoKitClient

    func reserve(
        for mainTransaction: TransactionSwap,
        feeAsset: AssetCoin,
        fee: Fee,
        policy: GasReservePolicy,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> GasReserveResult {
        let reserveResult: NodeRes<GasReserveResult>
        do {
            reserveResult = try await client.tx.calculateGasReserve(
                account: mainTransaction.account,
                energy: energyAccount(for: mainTransaction, feeAsset: feeAsset),
                amount: mainTransaction.amount,
                isMax: mainTransaction.isMax,
                fee: fee,
                policy: policy
            )
        } catch {
            throw .emulationFailed(
                kind: .unknown,
                reason: "chain kit failed to calculate gas reserve due to error: \(error.logDescription)"
            )
        }
        guard let reserve = reserveResult.getOrNull() else {
            let chainKitError = reserveResult.error
            let errorText = chainKitError.map(\.logValue) ?? "unknown"
            throw .emulationFailed(
                kind: ChainKitErrorKindClassifier.kind(nodeError: chainKitError),
                reason: "chain kit failed to calculate gas reserve due to error: \(errorText)"
            )
        }
        guard reserve.error == nil else {
            guard let amount = BigUInt(fee.amount.description) else {
                throw .emulationFailed(
                    kind: .insufficientBalance,
                    reason: "gas reserve reported insufficient balance for payload \(payloadId)"
                )
            }
            throw .insufficientNativeFee(
                shortage: MultichainNativeFeeShortage(
                    asset: MultichainAssetDetails(
                        assetId: feeAsset.id,
                        name: feeAsset.name,
                        symbol: feeAsset.symbol,
                        decimals: Int(feeAsset.decimals.value),
                        image: ""
                    ),
                    requiredAmount: amount
                )
            )
        }
        return reserve
    }

    private func energyAccount(for transaction: TransactionSwap, feeAsset: AssetCoin) -> ChainKit.Account {
        ChainKit.Account(
            address: transaction.account.address,
            asset: feeAsset,
            derivation: DerivationDefaultPath.shared,
            publicKey: transaction.account.publicKey
        )
    }
}
