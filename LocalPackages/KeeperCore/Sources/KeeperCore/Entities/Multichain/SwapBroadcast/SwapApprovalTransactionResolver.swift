import ChainKit

/// Resolves the ERC20 approve transaction that must precede a router-style swap
/// (the router pulls tokens via `transferFrom`, so an allowance is required).
/// Delegates calldata construction to ChainKit's `TransactionHelper` and picks the
/// exact or unlimited allowance per the user's toggle. When the aggregator did not
/// price the approve, falls back to the main fee scaled ×1.5 so the lower-nonce
/// approve is attractive enough to mine before the swap.
struct SwapApprovalTransactionResolver {
    let client: CryptoKitClient

    func resolveApprovalTransaction(
        mainTransaction: TransactionSwap,
        approvalData: String?,
        approvalFee: Fee?,
        mainFee: Fee,
        approvalMode: MultichainSwapApprovalMode
    ) -> SwapApprovalTransaction? {
        guard let approvalData,
              let transactions = client.tx.buildApproval(tx: mainTransaction, approvalData: approvalData)
        else {
            return nil
        }

        let transaction: TransactionCall
        switch approvalMode {
        case .exact:
            transaction = transactions.txExact
        case .unlimited:
            transaction = transactions.txMax
        }

        return SwapApprovalTransaction(
            transaction: transaction,
            fee: approvalFee ?? Self.scaledApprovalFee(from: mainFee)
        )
    }

    static func scaledApprovalFee(from fee: Fee) -> Fee {
        if let gas = fee as? FeeGas {
            let price = scaledBignum(gas.price, numerator: 3, denominator: 2)
            return FeeGas(
                limit: gas.limit,
                price: price,
                amount: gas.limit.multiply(other: price)
            )
        }
        if let eip1559 = fee as? FeeEip1559 {
            let maxPrice = scaledBignum(eip1559.maxPrice, numerator: 3, denominator: 2)
            let minerPrice = scaledBignum(eip1559.minerPrice, numerator: 3, denominator: 2)
            return FeeEip1559(
                limit: eip1559.limit,
                networkPrice: eip1559.networkPrice,
                maxPrice: maxPrice,
                minerPrice: minerPrice,
                amount: eip1559.limit.multiply(other: maxPrice)
            )
        }
        return fee
    }

    private static func scaledBignum(
        _ value: BignumBigInteger,
        numerator: Int32,
        denominator: Int32
    ) -> BignumBigInteger {
        value
            .multiply(other: BignumBigInteger.Companion.shared.fromInt(int: numerator))
            .divide(other: BignumBigInteger.Companion.shared.fromInt(int: denominator))
    }
}

/// An approve transaction ready to be signed together with the fee it should pay.
struct SwapApprovalTransaction {
    let transaction: TransactionCall
    let fee: Fee
}
