import BigInt
import Foundation

public extension MultichainSwapRoute {
    var quotedSourceAmount: BigUInt? {
        sourceAmount.flatMap { BigUInt($0) }
    }

    /// The cap an exact-output quote puts on the amount sold, slippage included; `nil` for exact input.
    var quotedMaximumSourceAmount: BigUInt? {
        maximumSourceAmount.flatMap { BigUInt($0) }
    }

    /// How much of `sourceAsset` the route actually takes out of the wallet, which is what a balance
    /// check has to compare against. A TON swap sends the traded amount and the gas the contracts
    /// forward in one message value, so `sourceAmount` understates what a native TON route needs;
    /// everywhere else the quote spends exactly what it quotes. `nil` mirrors an unquoted
    /// `sourceAmount`: the caller falls back to the entered amount.
    func spentSourceAmount(sourceAsset: MultichainAsset) -> BigUInt? {
        guard sourceAsset.isNative,
              sourceAsset.asset.chain == .ton,
              let main = payloads?.first(where: { $0.payloadKind == .main }),
              main.preparedPayloadType == .tonBOC,
              // Flexible calldata is rebuilt around whatever amount is sent, so only an exact
              // envelope pins the value that leaves the wallet.
              main.calldataPayloadType != .flex,
              let messageValues = MultichainSwapPayloadAdapter.tonMessageValues(main.payload)
        else {
            return quotedSourceAmount
        }
        return messageValues.reduce(0, +)
    }
}
