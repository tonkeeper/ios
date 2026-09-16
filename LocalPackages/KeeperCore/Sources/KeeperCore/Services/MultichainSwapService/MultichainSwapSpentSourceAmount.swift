import BigInt
import Foundation

public extension MultichainSwapRoute {
    /// How much of `sourceAsset` the route actually takes out of the wallet, which is what a balance
    /// check has to compare against. A TON swap sends the traded amount and the gas the contracts
    /// forward in one message value, so `sourceAmount` understates what a native TON route needs;
    /// everywhere else the quote spends exactly what it quotes. `nil` mirrors an unquoted
    /// `sourceAmount`: the caller falls back to the entered amount.
    func spentSourceAmount(sourceAsset: MultichainAsset) -> BigUInt? {
        let quoted = sourceAmount.flatMap { BigUInt($0) }
        guard sourceAsset.isNative,
              sourceAsset.asset.chain == .ton,
              let main = payloads?.first(where: { $0.payloadKind == .main }),
              main.preparedPayloadType == .tonBOC,
              // Flexible calldata is rebuilt around whatever amount is sent, so only an exact
              // envelope pins the value that leaves the wallet.
              main.calldataPayloadType != .flex,
              let messageValues = MultichainSwapPayloadAdapter.tonMessageValues(main.payload)
        else {
            return quoted
        }
        return messageValues.reduce(0, +)
    }
}
