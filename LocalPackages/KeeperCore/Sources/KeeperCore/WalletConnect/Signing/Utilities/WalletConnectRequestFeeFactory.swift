@preconcurrency import BigInt
import ChainKit
import Foundation

enum WalletConnectRequestFeeFactory {
    static func requestFee(
        payload: WalletConnectEVMTransaction,
        chain: WalletConnectChain
    ) throws(WalletConnectSigningError) -> (any Fee)? {
        let gasLimit = try payload.optionalEVMQuantity(.gas)
        let gasPrice = try positiveFeeValue(payload.optionalEVMQuantity(.gasPrice), field: .gasPrice)
        let maxFeePerGas = try positiveFeeValue(payload.optionalEVMQuantity(.maxFeePerGas), field: .maxFeePerGas)
        let maxPriorityFeePerGas = try positiveFeeValue(
            payload.optionalEVMQuantity(.maxPriorityFeePerGas),
            field: .maxPriorityFeePerGas
        )

        guard let gasLimit else {
            return nil
        }
        guard gasLimit > 0 else {
            throw .invalidTransaction(reason: "WalletConnect transaction gas must be greater than zero")
        }

        if chain.supportsEip1559Fees, maxFeePerGas != nil || maxPriorityFeePerGas != nil {
            return try eip1559Fee(
                gasLimit: gasLimit,
                gasPrice: gasPrice,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas
            )
        }

        if chain.supportsEip1559Fees, gasPrice == nil {
            return nil
        }

        guard let gasPrice else {
            if maxFeePerGas != nil || maxPriorityFeePerGas != nil {
                throw .invalidTransaction(reason: "WalletConnect transaction gasPrice is required for legacy fee")
            }
            return nil
        }

        return FeeGas(
            limit: bignum(gasLimit),
            price: bignum(gasPrice),
            amount: bignum(gasLimit * gasPrice)
        )
    }

    private static func eip1559Fee(
        gasLimit: BigUInt,
        gasPrice: BigUInt?,
        maxFeePerGas: BigUInt?,
        maxPriorityFeePerGas: BigUInt?
    ) throws(WalletConnectSigningError) -> FeeEip1559 {
        guard let maxFeePerGas,
              let maxPriorityFeePerGas
        else {
            throw .invalidTransaction(
                reason: "WalletConnect transaction EIP-1559 fee requires maxFeePerGas and maxPriorityFeePerGas"
            )
        }

        return FeeEip1559(
            limit: bignum(gasLimit),
            networkPrice: bignum(gasPrice ?? 0),
            maxPrice: bignum(maxFeePerGas),
            minerPrice: bignum(maxPriorityFeePerGas),
            amount: bignum(gasLimit * maxFeePerGas)
        )
    }

    private static func positiveFeeValue(
        _ value: @autoclosure () throws(WalletConnectSigningError) -> BigUInt?,
        field: WalletConnectEVMQuantityField
    ) throws(WalletConnectSigningError) -> BigUInt? {
        guard let parsed = try value() else {
            return nil
        }
        guard parsed > 0 else {
            throw .invalidTransaction(reason: "WalletConnect transaction \(field.rawValue) must be greater than zero")
        }
        return parsed
    }

    private static func bignum(_ value: BigUInt) -> BignumBigInteger {
        BignumBigInteger.Companion.shared.parseString(string: value.description, base: 10)
    }
}
