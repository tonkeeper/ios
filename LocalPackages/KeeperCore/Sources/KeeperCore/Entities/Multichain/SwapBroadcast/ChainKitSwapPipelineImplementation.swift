import BigInt
import ChainKit
import Foundation
import TKLogging

/// Orchestrates the client-side swap pipeline over stateless ChainKit stages:
/// normalize → fee → nonce → combined gas reserve → approve → sign → broadcast.
/// Preparation validates the complete route as one unit before confirmation.
final class ChainKitSwapPipelineImplementation: ChainKitSwapPipeline {
    private let stages: any SwapPipelineStageProvider
    private let assetDetailsProvider: (String, Wallet) async -> MultichainAssetDetails?
    private let feeResolver = SwapFeeResolver()

    convenience init(
        mnemonicAccess: MnemonicAccess,
        client: CryptoKitClient,
        assetDetailsProvider: @escaping (String, Wallet) async -> MultichainAssetDetails? = { _, _ in nil }
    ) {
        self.init(
            stages: SwapPipelineStageProviderImplementation(
                mnemonicAccess: mnemonicAccess,
                client: client
            ),
            assetDetailsProvider: assetDetailsProvider
        )
    }

    init(
        stages: any SwapPipelineStageProvider,
        assetDetailsProvider: @escaping (String, Wallet) async -> MultichainAssetDetails? = { _, _ in nil }
    ) {
        self.stages = stages
        self.assetDetailsProvider = assetDetailsProvider
    }

    func prepareSwapPayloads(
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        provider: MultichainSwapProvider
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPipelinePreparation {
        Log.multichainSwap.i(
            "ChainKit route preparation started",
            extraInfo: swapPayloadsLogInfo(
                payloads: payloads.all,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset
            )
        )
        let route = try normalizedPayloads(
            wallet: wallet,
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            payloads: payloads,
            provider: provider,
            sourcePublicKey: storedPublicKey(for: sourceAsset, wallet: wallet),
            destinationPublicKey: storedPublicKey(for: destinationAsset, wallet: wallet)
        )
        let main = route.main
        let mainFee: any Fee
        do {
            mainFee = try await stages.resolveFee(
                transaction: main.normalized.transaction,
                payloadFee: main.normalized.fee,
                networkType: main.normalized.networkType,
                payloadId: main.payload.payloadId
            )
        } catch {
            mainFee = try await fallbackFee(
                after: error,
                main: main,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset
            )
        }

        var payloadFees = [main.payload.payloadId: mainFee] as [String: any Fee]
        var pricedPayloads = [(PreparedSwapPayload, any Fee)]()
        pricedPayloads.append((main, mainFee))
        var reserveFees: [any Fee] = [mainFee]
        var requiresApproval = false

        if let approvalPayload = route.approval {
            guard let approval = stages.buildApproval(
                mainTransaction: main.normalized.transaction,
                approvalData: approvalPayload.normalized.approvalData,
                approvalFee: approvalPayload.normalized.fee,
                mainFee: mainFee,
                approvalMode: .exact
            ) else {
                throw invalidApprovalFailure(approvalPayload)
            }
            payloadFees[approvalPayload.payload.payloadId] = approval.fee
            pricedPayloads.append((approvalPayload, approval.fee))
            reserveFees.append(approval.fee)
            requiresApproval = true
        }

        let batteryPayload = main.normalized.batteryPayload
        let nativeFeeShortage = try await reservedNativeFeeShortage(
            main: main,
            reserveFees: reserveFees,
            hasBatteryPayload: batteryPayload != nil
        )

        var fees = [MultichainTransactionEmulationResult]()
        for (payload, fee) in pricedPayloads {
            try fees.append(
                await emulationResult(
                    fee: fee,
                    normalized: payload.normalized,
                    wallet: wallet
                )
            )
        }

        Log.multichainSwap.i(
            "ChainKit route preparation completed",
            extraInfo: swapPayloadsLogInfo(
                payloads: payloads.all,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                additional: [
                    "requiresApproval": requiresApproval ? "true" : "false",
                    "nativeFeeShortage": nativeFeeShortage == nil ? "false" : "true",
                ]
            )
        )
        return MultichainSwapPipelinePreparation(
            fees: fees,
            payloadFees: MultichainSwapPayloadFees(payloadFees),
            requiresApproval: requiresApproval,
            batteryPayload: batteryPayload,
            nativeFeeShortage: nativeFeeShortage
        )
    }

    func executeSwapPayloads(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        payloadFees: MultichainSwapPayloadFees,
        provider: MultichainSwapProvider,
        approvalMode: MultichainSwapApprovalMode
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapBroadcastResult {
        Log.multichainSwap.i(
            "ChainKit swap broadcast started",
            extraInfo: swapPayloadsLogInfo(
                payloads: payloads.all,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                additional: ["approvalMode": approvalMode.rawValue]
            )
        )
        guard case .Regular = wallet.identity.kind else {
            throw .internal(reason: "wallet type is not supported for multichain swaps")
        }

        let preflight = try normalizedPayloads(
            wallet: wallet,
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            payloads: payloads,
            provider: provider,
            sourcePublicKey: storedPublicKey(for: sourceAsset, wallet: wallet),
            destinationPublicKey: storedPublicKey(for: destinationAsset, wallet: wallet)
        )
        let preflightMain = preflight.main
        let mainFee = try await stages.resolveFee(
            transaction: preflightMain.normalized.transaction,
            payloadFee: payloadFees.fee(for: preflightMain.payload.payloadId) ?? preflightMain.normalized.fee,
            networkType: preflightMain.normalized.networkType,
            payloadId: preflightMain.payload.payloadId
        )

        let preflightApproval = preflight.approval
        let approvalFee: (any Fee)?
        if let preflightApproval {
            guard let approval = try stages.buildApproval(
                mainTransaction: preflightMain.normalized.transaction,
                approvalData: preflightApproval.normalized.approvalData,
                approvalFee: payloadFees.fee(for: preflightApproval.payload.payloadId) ?? preflightApproval.normalized.fee,
                mainFee: mainFee,
                approvalMode: approvalMode
            ) else {
                throw invalidApprovalFailure(preflightApproval)
            }
            approvalFee = approval.fee
        } else {
            approvalFee = nil
        }

        let chainKitWallet = try await stages.unlockSigningWallet(
            passcodeProvider: passcodeProvider,
            wallet: wallet
        )
        let sourcePublicKey = chainKitWallet.getPublicKey(
            chain: preflightMain.normalized.sourceChain.asChainKitChain
        )
        let destinationPublicKey = destinationAsset.asset.chain.map {
            chainKitWallet.getPublicKey(chain: $0.asChainKitChain)
        }
        let preparedRoute = try normalizedPayloads(
            wallet: wallet,
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            payloads: payloads,
            provider: provider,
            sourcePublicKey: sourcePublicKey,
            destinationPublicKey: destinationPublicKey
        )
        let main = preparedRoute.main
        let nonce = try await stages.nonce(
            account: main.normalized.transaction.account,
            networkType: main.normalized.networkType,
            payloadId: main.payload.payloadId
        )
        let combinedFee = feeResolver.combinedFee([mainFee] + [approvalFee].compactMap { $0 })
        let gasReserve = try await stages.reserve(
            transaction: main.normalized.transaction,
            feeAsset: main.normalized.feeAsset,
            fee: combinedFee,
            policy: main.normalized.gasReservePolicy,
            payloadId: main.payload.payloadId
        )
        let mainTransaction = SwapTransactionAdjuster.adjustedTransaction(
            main.normalized.transaction,
            gasReserve: gasReserve,
            calldataType: main.normalized.calldataType
        )

        var broadcastedPayloads = [MultichainSwapBroadcastedPayload]()
        var mainNonce = nonce
        if let approvalPayload = preparedRoute.approval {
            guard let approval = stages.buildApproval(
                mainTransaction: mainTransaction,
                approvalData: approvalPayload.normalized.approvalData,
                approvalFee: approvalFee,
                mainFee: mainFee,
                approvalMode: approvalMode
            ) else {
                throw invalidApprovalFailure(approvalPayload)
            }
            let approvalHash = try await signAndSendSwap(
                transaction: approval.transaction,
                fee: approval.fee,
                nonce: nonce,
                normalized: main.normalized,
                wallet: chainKitWallet,
                payload: approvalPayload.payload,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset
            )
            broadcastedPayloads.append(
                MultichainSwapBroadcastedPayload(
                    payloadId: approvalPayload.payload.payloadId,
                    kind: approvalPayload.payload.kind,
                    payloadType: approvalPayload.payload.payloadType,
                    txHash: approvalHash
                )
            )
            mainNonce = nonce.add(other: BignumBigInteger.Companion.shared.ONE)
        }

        let mainHash = try await signAndSendSwap(
            transaction: mainTransaction,
            fee: mainFee,
            nonce: mainNonce,
            normalized: main.normalized,
            wallet: chainKitWallet,
            payload: main.payload,
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset
        )
        broadcastedPayloads.append(
            MultichainSwapBroadcastedPayload(
                payloadId: main.payload.payloadId,
                kind: main.payload.kind,
                payloadType: main.payload.payloadType,
                txHash: mainHash
            )
        )

        return MultichainSwapBroadcastResult(
            txHash: mainHash,
            broadcastedPayloads: broadcastedPayloads
        )
    }
}

private extension ChainKitSwapPipelineImplementation {
    func storedPublicKey(for asset: MultichainAsset, wallet: Wallet) -> PubKey? {
        guard case let .multichain(state) = wallet.multichain,
              let chain = asset.asset.chain
        else {
            return nil
        }
        return state.walletAddress(
            for: chain,
            preferredType: wallet.preferredMultichainAddressType(for: chain)
        )?.publicKey?.chainKitPubKey
    }

    func normalizedPayloads(
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        provider: MultichainSwapProvider,
        sourcePublicKey: PubKey? = nil,
        destinationPublicKey: PubKey? = nil
    ) throws(MultichainSwapExecutionFailure) -> (main: PreparedSwapPayload, approval: PreparedSwapPayload?) {
        do {
            let adapter = MultichainSwapPayloadAdapter()
            func normalize(_ payload: MultichainSwapPreparedPayload) throws -> PreparedSwapPayload {
                let normalized = try adapter.normalize(
                    wallet: wallet,
                    sourceAsset: sourceAsset,
                    destinationAsset: destinationAsset,
                    payload: payload,
                    provider: provider,
                    sourcePublicKey: sourcePublicKey,
                    destinationPublicKey: destinationPublicKey
                )
                return PreparedSwapPayload(payload: payload, normalized: normalized)
            }
            return try (main: normalize(payloads.main), approval: payloads.approval.map(normalize))
        } catch {
            throw SwapExecutionFailureMapper.failure(from: error)
        }
    }

    /// A chain that prices a transfer by emulating it cannot price one the wallet has no coin to
    /// send: the node rejects the message before execution, and the failure arrives untyped. The
    /// reserve answers the same question from the balance, so put the chain's default fee to it
    /// first — pricing the main payload alone keeps that a lower bound, enough to prove a shortage
    /// and never enough to invent one. A relayable route survives the shortage the way it survives
    /// one found later, on an estimate no signed message sees: the relayer prices its own, and a
    /// native send is barred by the very shortage just proven.
    func fallbackFee(
        after failure: MultichainSwapExecutionFailure,
        main: PreparedSwapPayload,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset
    ) async throws(MultichainSwapExecutionFailure) -> any Fee {
        let defaultFee: any Fee
        do {
            defaultFee = try await stages.defaultFee(
                transaction: main.normalized.transaction,
                networkType: main.normalized.networkType,
                payloadId: main.payload.payloadId
            )
        } catch {
            throw failure
        }
        let reserveFailure: MultichainSwapExecutionFailure?
        do {
            _ = try await stages.reserve(
                transaction: main.normalized.transaction,
                feeAsset: main.normalized.feeAsset,
                fee: defaultFee,
                policy: main.normalized.gasReservePolicy,
                payloadId: main.payload.payloadId
            )
            reserveFailure = nil
        } catch {
            reserveFailure = error
        }
        guard let shortage = reserveFailure, case .insufficientNativeFee = shortage else {
            throw failure
        }
        Log.multichainSwap.w(
            "fee resolution failed on a wallet short of the chain coin",
            error: failure,
            extraInfo: swapPayloadLogInfo(
                payload: main.payload,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                additional: [
                    "feeAsset": main.normalized.feeAsset.id,
                    "hasBatteryPayload": main.normalized.batteryPayload == nil ? "false" : "true",
                ]
            )
        )
        guard main.normalized.batteryPayload != nil else {
            throw shortage
        }
        return defaultFee
    }

    /// A wallet that cannot cover the chain's own fee still has a route worth confirming when a
    /// battery method can pay for it — the shortage then belongs to one fee option rather than to
    /// the whole preparation. Without such a method the reserve stays fatal.
    func reservedNativeFeeShortage(
        main: PreparedSwapPayload,
        reserveFees: [any Fee],
        hasBatteryPayload: Bool
    ) async throws(MultichainSwapExecutionFailure) -> MultichainNativeFeeShortage? {
        do {
            _ = try await stages.reserve(
                transaction: main.normalized.transaction,
                feeAsset: main.normalized.feeAsset,
                fee: feeResolver.combinedFee(reserveFees),
                policy: main.normalized.gasReservePolicy,
                payloadId: main.payload.payloadId
            )
            return nil
        } catch {
            guard hasBatteryPayload, case let .insufficientNativeFee(shortage) = error else {
                throw error
            }
            return shortage
        }
    }

    func invalidApprovalFailure(_ approvalPayload: PreparedSwapPayload) -> MultichainSwapExecutionFailure {
        .invalidPayload(
            payloadId: approvalPayload.payload.payloadId,
            reason: "ChainKit could not build the required approval transaction"
        )
    }

    func emulationResult(
        fee: any Fee,
        normalized: MultichainSwapPayloadAdapter.Normalized,
        wallet: Wallet
    ) async throws(MultichainSwapExecutionFailure) -> MultichainTransactionEmulationResult {
        let amount: BigUInt
        do {
            amount = try feeResolver.amount(of: fee)
        } catch {
            throw SwapExecutionFailureMapper.failure(from: error)
        }
        let details = await assetDetailsProvider(normalized.feeAsset.id, wallet)
        return MultichainTransactionEmulationResult(
            fee: amount,
            asset: details ?? MultichainAssetDetails(
                assetId: normalized.feeAsset.id,
                name: normalized.feeAsset.name,
                symbol: normalized.feeAsset.symbol,
                decimals: Int(normalized.feeAsset.decimals.value),
                image: ""
            )
        )
    }

    func signAndSendSwap(
        transaction: any ChainKit.Transaction,
        fee: any Fee,
        nonce: BignumBigInteger,
        normalized: MultichainSwapPayloadAdapter.Normalized,
        wallet: CryptoWallet,
        payload: MultichainSwapPreparedPayload,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset
    ) async throws(MultichainSwapExecutionFailure) -> String {
        Log.multichainSwap.i(
            "ChainKit swap sign and broadcast started",
            extraInfo: swapPayloadLogInfo(
                payload: payload,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                additional: ["sourceChain": normalized.sourceChain.rawValue]
            )
        )
        return try await stages.signAndBroadcast(
            transaction: transaction,
            fee: fee,
            nonce: nonce,
            sourceChain: normalized.sourceChain,
            networkType: normalized.networkType,
            wallet: wallet,
            payloadId: payload.payloadId
        )
    }
}

private struct PreparedSwapPayload {
    let payload: MultichainSwapPreparedPayload
    let normalized: MultichainSwapPayloadAdapter.Normalized
}
