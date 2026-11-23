import BigInt
import Foundation
import TKBatteryAPI
import TKLogging

/// The swap's relayed fee engines, bound to the wallet a deposit pays from: battery charges or a
/// token of the source chain pay the source fee instead of the chain's own coin.
struct PerpsDepositRelaying {
    let swapWallet: MultichainSwapWallet
    let resolver: MultichainSwapFeeMethodResolver

    /// Only a deposit the backend names by its execution can go through the relayer: a direct one
    /// is recorded by its transaction hash, which the relayer may leave unnamed. The relayer
    /// carries one call, or a Hermes batch as the quote has it, delegating the address itself when
    /// it has to. An approval in a transaction of its own, or a
    /// delegation riding on a single call, keeps the chain's own coin paying. So does an Omniston
    /// message: it states its bounce and mode, and the relayer rebuilds a message without them.
    func context(quote: PerpsDepositQuote, walletAsset: MultichainAsset) -> MultichainSwapFeeContext? {
        let chain = quote.sourceAsset.chain
        let shape = [
            "quote": quote.quoteId,
            "route": "\(quote.route)",
            "chain": chain.rawValue,
            "payloads": quote.payloads.map { "\($0.kind)\($0.delegation == nil ? "" : "+delegation")" }.joined(separator: ","),
        ]
        guard quote.route == .crosschainSwap,
              quote.provider != .omniston,
              quote.payloads.count == 1,
              let main = quote.payloads.first,
              let spent = BigUInt(quote.sourceAmountUnits, radix: 10)
        else {
            Log.perps.i("Deposit relay not offered: shape", extraInfo: shape)
            return nil
        }
        let payload: MultichainSwapBatteryPayload?
        switch main.kind {
        case .main where main.delegation == nil:
            payload = BigUInt(main.valueUnits, radix: 10).flatMap {
                Self.payload(main, chain: chain, sender: quote.sender, assetId: quote.sourceAsset.raw, value: $0)
            }
        case .batch:
            payload = Self.batch(main, of: quote)
        default:
            payload = nil
        }
        guard let payload else {
            Log.perps.i("Deposit relay not offered: payload", extraInfo: shape)
            return nil
        }
        Log.perps.i("Deposit relay context", extraInfo: shape.merging(["relayed": payload.logValue]) { $1 })
        return MultichainSwapFeeContext(
            swapWallet: swapWallet,
            sourceAsset: walletAsset,
            payloadId: main.payloadId,
            requiresApproval: false,
            payload: payload,
            spentSourceAmount: spent
        )
    }

    func options(context: MultichainSwapFeeContext) async -> [MultichainSwapFeeOption] {
        await resolver.options(context: context, nativeFees: [])
    }

    func engine(for context: MultichainSwapFeeContext) -> (any MultichainSwapRelayedFeeEngine)? {
        resolver.engine(payload: context.payload)
    }

    /// TRON's relayer rebuilds a plain transfer only, and a deposit calls the token contract.
    private static func payload(
        _ main: PerpsDepositQuotePayload,
        chain: MultichainChain,
        sender: String,
        assetId: String,
        value: BigUInt
    ) -> MultichainSwapBatteryPayload? {
        switch chain {
        case .ton:
            return .ton([TonSwapMessage(to: main.to, amount: value, payload: main.data, stateInit: nil)])
        case .eth, .base, .arb, .bsc, .polygon, .avax, .robinhood:
            return EVMGaslessCall.swap(chain: chain, sender: sender, assetId: assetId, to: main.to, amount: value, data: main.data)
                .map { .evm(EVMSwapRelay(chain: chain, call: $0)) }
        case .tron, .btc, .sol:
            return nil
        }
    }

    private static func batch(_ main: PerpsDepositQuotePayload, of quote: PerpsDepositQuote) -> MultichainSwapBatteryPayload? {
        let payloads: [Components.Schemas.GaslessV2Payload]
        do {
            payloads = try JSONDecoder().decode([Components.Schemas.GaslessV2Payload].self, from: Data(quote.operation.payloads.utf8))
        } catch {
            Log.perps.w("Deposit relay: batch unreadable payload=\(main.payloadId)", error: error)
            return nil
        }
        guard let payload = payloads.first(where: { $0.id == main.payloadId }),
              let calls = try? PerpsDepositCalldata.readBatch(main)
        else { return nil }
        return .evmBatch(EVMBatchRelay(
            chain: quote.sourceAsset.chain,
            sender: quote.sender,
            payload: payload,
            calls: calls.map { HermesExecute.Call(target: $0.to, value: $0.valueUnits, data: $0.data ?? "") }
        ))
    }
}

extension MultichainSwapExecutionFailure {
    /// Only a broadcast that went unanswered may have reached the relayer; anything else failed before.
    var mayHaveRelayed: Bool {
        if case .broadcastFailed = self { return true }
        return false
    }
}
