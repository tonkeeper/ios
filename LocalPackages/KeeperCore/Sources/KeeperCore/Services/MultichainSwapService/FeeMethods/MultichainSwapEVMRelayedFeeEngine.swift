@preconcurrency import BigInt
import Foundation
import TKLogging

/// Relays an EVM swap through the battery's gasless relayer, which pays the chain and takes its fee
/// in battery charges or in a token of the chain. The route's call goes out exactly as quoted; the
/// relayer only decides who pays the gas.
struct MultichainSwapEVMRelayedFeeEngine: MultichainSwapRelayedFeeEngine {
    let chain: MultichainChain

    private let relayer: EVMGaslessRelaying
    private let signer: MultichainRelayedOperationSigner
    private let relayedChains: () async -> Set<MultichainChain>?
    /// The remote battery switches; the wallet's own are read here.
    private let isRelayerEnabled: (Wallet) async -> Bool
    private let batteryCharges: (Wallet) async -> BatteryChargesAvailability
    /// The wallet's own entries for assets other than the one being sold, by the ids they are asked
    /// for; an asset the wallet does not list, or whose listing cannot be read, is missing from the answer.
    private let walletTokens: (_ assetIds: [String], _ wallet: Wallet) async -> [String: MultichainAsset]

    init(
        chain: MultichainChain,
        relayer: EVMGaslessRelaying,
        signer: MultichainRelayedOperationSigner,
        relayedChains: @escaping () async -> Set<MultichainChain>?,
        isRelayerEnabled: @escaping (Wallet) async -> Bool,
        batteryCharges: @escaping (Wallet) async -> BatteryChargesAvailability,
        walletTokens: @escaping (_ assetIds: [String], _ wallet: Wallet) async -> [String: MultichainAsset]
    ) {
        self.chain = chain
        self.relayer = relayer
        self.signer = signer
        self.relayedChains = relayedChains
        self.isRelayerEnabled = isRelayerEnabled
        self.batteryCharges = batteryCharges
        self.walletTokens = walletTokens
    }

    /// Battery first, then the sold asset, then any other token of the chain the relayer prices.
    func options(context: MultichainSwapFeeContext) async -> [MultichainSwapFeeOption] {
        guard let relay = await relay(context: context) else {
            return []
        }
        let estimations: [EVMGaslessEstimation]
        do {
            estimations = try await relayer.estimate(wallet: context.wallet, call: relay.call)
        } catch {
            Log.multichainSwap.w(
                "relayed evm swap estimate failed, the swap keeps the chain fee",
                error: error,
                extraInfo: ["payloadId": context.payloadId]
            )
            return []
        }
        // A token the relayer rules out cannot pay whatever the balance, so it is not looked up.
        let heldTokens = await loadWalletTokens(
            of: estimations.filter { !$0.isBattery && $0.isAvailable }.map(\.asset.id),
            context: context
        )
        var battery = [MultichainSwapFeeOption]()
        var sold = [MultichainSwapFeeOption]()
        var others = [MultichainSwapFeeOption]()
        for estimation in estimations {
            if estimation.isBattery {
                let charges = Int(clamping: estimation.fee)
                guard charges > 0 else {
                    continue
                }
                let availableCharges = await batteryCharges(context.wallet)
                battery.append(
                    MultichainSwapFeeOption(
                        cost: .batteryCharges(
                            count: charges,
                            excess: nil,
                            isInsufficient: !estimation.isAvailable
                                || Self.isInsufficient(charges: charges, availableCharges: availableCharges)
                        )
                    )
                )
                continue
            }
            let isSold = AssetIdComponents.isSameAsset(estimation.asset.id, context.sourceAsset.asset.assetId)
            let held = heldTokens[estimation.asset.id]
            // The method and its deposit go by the wallet's id for the token, as the sold one does;
            // the relayer's spelling is looked up again when sending.
            let asset = isSold ? context.sourceAsset.asset : held?.asset ?? MultichainAssetDetails(
                assetId: estimation.asset.id,
                name: estimation.asset.name,
                symbol: estimation.asset.symbol,
                decimals: estimation.asset.decimals,
                image: estimation.asset.image ?? ""
            )
            let cannotPay = isTokenInsufficient(
                asset: asset,
                fee: estimation.fee,
                context: context,
                balance: held?.balance
            )
            let option = MultichainSwapFeeOption(
                cost: .token(asset, amount: estimation.fee, isInsufficient: !estimation.isAvailable || cannotPay)
            )
            if isSold {
                sold.append(option)
            } else {
                others.append(option)
            }
        }
        let options = battery + sold + others
        Log.multichainSwap.i(
            "relayed evm swap priced",
            extraInfo: [
                "payloadId": context.payloadId,
                "feeMethods": options.map(\.logValue).joined(separator: ","),
            ]
        )
        return options
    }

    /// The relayer broadcasts on its own and names no transaction, so a relayed EVM swap returns no
    /// hash: there is nothing to track until the relayer's transaction shows up in the history.
    func send(
        context: MultichainSwapFeeContext,
        confirmed: MultichainSwapRelayedFee,
        passcodeProvider: @escaping () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> String? {
        let payloadId = context.payloadId
        guard let relay = await relay(context: context) else {
            throw .internal(reason: "no relayed method can pay for swap payload \(payloadId)")
        }
        // The relayer's own id of the confirmed asset comes from a fresh estimate: the one the option
        // was priced from is not kept, and the price is checked again below anyway.
        let estimations: [EVMGaslessEstimation]
        do {
            estimations = try await relayer.estimate(wallet: context.wallet, call: relay.call)
        } catch {
            throw .preparationFailed(
                kind: .networkError,
                reason: "failed to re-price swap payload \(payloadId) with the relayer: \(error.logDescription)"
            )
        }
        let assetId: String
        switch confirmed {
        case .batteryCharges:
            guard let battery = estimations.first(where: \.isBattery) else {
                throw .preparationFailed(kind: .unknown, reason: "battery no longer prices swap payload \(payloadId)")
            }
            assetId = battery.asset.id
        case let .token(confirmedAssetId, _):
            guard let token = estimations.first(where: { !$0.isBattery && AssetIdComponents.isSameAsset($0.asset.id, confirmedAssetId) }) else {
                throw .preparationFailed(kind: .unknown, reason: "the relayer no longer prices swap payload \(payloadId) in \(confirmedAssetId)")
            }
            assetId = token.asset.id
        case .gram:
            throw .internal(reason: "an evm swap cannot be relayed against GRAM")
        }

        let emulation: EVMGaslessEmulation
        do {
            emulation = try await relayer.emulate(wallet: context.wallet, call: relay.call, assetId: assetId)
        } catch {
            throw .preparationFailed(
                kind: .networkError,
                reason: "failed to emulate swap payload \(payloadId) with the relayer: \(error.logDescription)"
            )
        }
        try await requireConfirmedPrice(confirmed, emulation: emulation, context: context)

        let signedOperation: Data
        do {
            signedOperation = try await signer.signRelayedOperation(
                passcodeProvider: passcodeProvider,
                wallet: context.wallet,
                chain: chain,
                operation: emulation.operation
            )
        } catch {
            throw Self.failure(signing: error, payloadId: payloadId)
        }

        do {
            try await relayer.send(wallet: context.wallet, signedOperation: signedOperation)
        } catch {
            Log.multichainSwap.w(
                "relayed evm swap failed",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            throw Self.failure(sending: error, payloadId: payloadId)
        }
        return nil
    }
}

private extension MultichainSwapEVMRelayedFeeEngine {
    /// The relay the engine answers for, or nil when nothing relayed may be offered: the relayer must
    /// serve the chain, there must be nothing to approve first, the wallet must sign with the HD keys
    /// an EVM address derives from, and the relayer must be switched on remotely and by the wallet itself.
    func relay(context: MultichainSwapFeeContext) async -> EVMSwapRelay? {
        guard case let .evm(relay) = context.payload, relay.chain == chain else {
            return nil
        }
        guard await relayedChains()?.contains(chain) == true else {
            Log.multichainSwap.i(
                "relayed evm swap not offered: relayer does not serve the chain",
                extraInfo: ["payloadId": context.payloadId, "chain": chain.rawValue]
            )
            return nil
        }
        let wallet = context.wallet
        guard !context.requiresApproval,
              context.swapWallet.keys == .hd,
              wallet.kind == .regular,
              wallet.network.isMainnet,
              context.swapWallet.address(for: chain) != nil
        else {
            Log.multichainSwap.i(
                "relayed evm swap not offered",
                extraInfo: [
                    "payloadId": context.payloadId,
                    "chain": chain.rawValue,
                    "requiresApproval": "\(context.requiresApproval)",
                ]
            )
            return nil
        }
        let isRelayerEnabled = await isRelayerEnabled(wallet)
        guard MultichainSwapBatteryFeeRules.isBatteryAllowed(
            wallet: wallet,
            isBatteryEnabled: isRelayerEnabled,
            isBatterySendEnabled: isRelayerEnabled
        ) else {
            Log.multichainSwap.i(
                "relayed evm swap not offered: relayer switched off",
                extraInfo: ["payloadId": context.payloadId, "relayerEnabled": "\(isRelayerEnabled)"]
            )
            return nil
        }
        return relay
    }

    /// The wallet's entries for the tokens `assetIds` name, read together; the sold token comes with the route.
    func loadWalletTokens(of assetIds: [String], context: MultichainSwapFeeContext) async -> [String: MultichainAsset] {
        let others = assetIds.filter { !AssetIdComponents.isSameAsset($0, context.sourceAsset.asset.assetId) }
        guard !others.isEmpty else {
            return [:]
        }
        return await walletTokens(others, context.wallet)
    }

    /// A fee in the sold asset has to fit next to what the swap takes out of it, not just under the
    /// balance — and a route that did not say how much it takes leaves that unverifiable, so the
    /// method cannot pay. A balance that cannot be read cannot cover anything either.
    func isTokenInsufficient(
        asset: MultichainAssetDetails,
        fee: BigUInt,
        context: MultichainSwapFeeContext,
        balance: BigUInt?
    ) -> Bool {
        if AssetIdComponents.isSameAsset(asset.assetId, context.sourceAsset.asset.assetId) {
            guard let spent = context.spentSourceAmount else {
                return true
            }
            return fee + spent > context.sourceAsset.balance
        }
        guard let balance else {
            return true
        }
        return fee > balance
    }

    /// Holds the relayer to the price the user confirmed, and the wallet to covering it now.
    func requireConfirmedPrice(
        _ confirmed: MultichainSwapRelayedFee,
        emulation: EVMGaslessEmulation,
        context: MultichainSwapFeeContext
    ) async throws(MultichainSwapExecutionFailure) {
        let payloadId = context.payloadId
        switch confirmed {
        case let .batteryCharges(confirmedCharges):
            try MultichainSwapBatteryFeeRules.requireQuote(
                Int(clamping: emulation.fee),
                confirmedCharges: confirmedCharges,
                available: await batteryCharges(context.wallet),
                payloadId: payloadId
            )
        case let .token(assetId, confirmedAmount):
            try MultichainSwapBatteryFeeRules.requireTokenQuote(
                emulation.fee,
                confirmedAmount: confirmedAmount,
                payloadId: payloadId
            )
            let asset = AssetIdComponents.isSameAsset(assetId, context.sourceAsset.asset.assetId)
                ? context.sourceAsset.asset
                : MultichainAssetDetails(assetId: assetId, name: "", symbol: "", decimals: 0, image: "")
            let heldTokens = await loadWalletTokens(of: [assetId], context: context)
            guard !isTokenInsufficient(asset: asset, fee: emulation.fee, context: context, balance: heldTokens[assetId]?.balance) else {
                throw .preparationFailed(
                    kind: .insufficientBalance,
                    reason: "\(assetId) no longer covers the fee of swap payload \(payloadId)"
                )
            }
        case .gram:
            throw .internal(reason: "an evm swap cannot be relayed against GRAM")
        }
    }

    static func isInsufficient(charges: Int, availableCharges: BatteryChargesAvailability) -> Bool {
        switch availableCharges {
        case .unavailable:
            return true
        case .unknown:
            return false
        case let .available(available):
            return available < charges
        }
    }

    static func failure(signing error: MultichainTransactionFailure, payloadId: String) -> MultichainSwapExecutionFailure {
        switch error {
        case .canceled:
            return .canceled
        case let .failedToSign(kind, reason):
            return .signingFailed(payloadId: payloadId, kind: kind, reason: reason)
        default:
            return .signingFailed(payloadId: payloadId, kind: .signInternalError, reason: error.logDescription)
        }
    }

    /// What the relayer refused before broadcasting may be sent again after a fresh quote; what it
    /// did not answer about may already be on its way, so the slider must not be re-armed.
    static func failure(sending error: any Error, payloadId: String) -> MultichainSwapExecutionFailure {
        if let relayerError = error as? EVMGaslessRelayerError {
            switch relayerError {
            case .quoteExpired:
                return .preparationFailed(
                    kind: .networkError,
                    reason: "the relayer no longer holds the emulated swap payload \(payloadId)"
                )
            case let .rejected(reason):
                return .preparationFailed(kind: .unknown, reason: "the relayer refused swap payload \(payloadId): \(reason)")
            case let .malformedEnvelope(reason):
                return .internal(reason: "the signed swap payload \(payloadId) is not a relayer envelope: \(reason)")
            }
        }
        return .broadcastFailed(
            payloadId: payloadId,
            kind: .networkError,
            reason: "the relayer did not answer for swap payload \(payloadId): \(error.logDescription)"
        )
    }
}
