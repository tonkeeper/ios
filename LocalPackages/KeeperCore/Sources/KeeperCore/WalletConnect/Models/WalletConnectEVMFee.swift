@preconcurrency import BigInt
import ChainKit

/// The network fee the wallet priced an EVM request at: the confirmation shows its amount and the
/// transaction is signed with exactly this fee.
public struct WalletConnectEVMFee: Sendable, Equatable {
    public let amount: BigUInt
    let limit: BigUInt
    let price: Price

    enum Price: Sendable, Equatable {
        case gas(price: BigUInt)
        case eip1559(networkPrice: BigUInt, maxPrice: BigUInt, minerPrice: BigUInt)
    }
}

extension WalletConnectEVMFee {
    init(fee: any Fee) throws(WalletConnectSigningError) {
        switch fee {
        case let fee as FeeGas:
            try self.init(
                amount: Self.bigUInt(fee.amount),
                limit: Self.bigUInt(fee.limit),
                price: .gas(price: Self.bigUInt(fee.price))
            )
        case let fee as FeeEip1559:
            try self.init(
                amount: Self.bigUInt(fee.amount),
                limit: Self.bigUInt(fee.limit),
                price: .eip1559(
                    networkPrice: Self.bigUInt(fee.networkPrice),
                    maxPrice: Self.bigUInt(fee.maxPrice),
                    minerPrice: Self.bigUInt(fee.minerPrice)
                )
            )
        default:
            throw .failedToCalculateFee(reason: "chainkit priced the transaction with an unsupported fee \(type(of: fee))")
        }
    }

    func chainKitFee(chain: WalletConnectChain) -> any Fee {
        let asset = chain.multichainChain.asChainKitChain.toAsset()
        switch price {
        case let .gas(price):
            return FeeGas(
                asset: asset,
                limit: Self.bignum(limit),
                price: Self.bignum(price),
                amount: Self.bignum(amount)
            )
        case let .eip1559(networkPrice, maxPrice, minerPrice):
            return FeeEip1559(
                asset: asset,
                limit: Self.bignum(limit),
                networkPrice: Self.bignum(networkPrice),
                maxPrice: Self.bignum(maxPrice),
                minerPrice: Self.bignum(minerPrice),
                amount: Self.bignum(amount)
            )
        }
    }
}

private extension WalletConnectEVMFee {
    static func bigUInt(_ value: BignumBigInteger) throws(WalletConnectSigningError) -> BigUInt {
        guard let parsed = BigUInt(value.description) else {
            throw .failedToCalculateFee(reason: "chainkit priced the transaction with a fee that is not a uint: \(value.description)")
        }
        return parsed
    }

    static func bignum(_ value: BigUInt) -> BignumBigInteger {
        BignumBigInteger.Companion.shared.parseString(string: value.description, base: 10)
    }
}
