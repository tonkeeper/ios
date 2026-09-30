import BigInt
import ChainKit
import Foundation
import TKLogging

public protocol MultichainSwapExecutionService {
    func prepareExecutionPlan(
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        route: MultichainSwapRoute
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan

    func execute(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        approvalMode: MultichainSwapApprovalMode,
        feeMethod: MultichainSwapFeeMethod
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult
}

final class MultichainSwapExecutionServiceImplementation: MultichainSwapExecutionService {
    private let swapService: MultichainSwapService
    private let swapPipeline: ChainKitSwapPipeline
    private let pendingTransactionsService: PendingTransactionsService
    private let feeMethodResolver: MultichainSwapFeeMethodResolver
    private let now: () -> Date

    init(
        swapService: MultichainSwapService,
        swapPipeline: ChainKitSwapPipeline,
        pendingTransactionsService: PendingTransactionsService,
        feeMethodResolver: MultichainSwapFeeMethodResolver,
        now: @escaping () -> Date = Date.init
    ) {
        self.swapService = swapService
        self.swapPipeline = swapPipeline
        self.pendingTransactionsService = pendingTransactionsService
        self.feeMethodResolver = feeMethodResolver
        self.now = now
    }

    func prepareExecutionPlan(
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        route: MultichainSwapRoute
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan {
        func routeInfo(_ additional: [String: String] = [:]) -> [String: String] {
            Self.routeLogInfo(
                route: route,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                additional: additional
            )
        }
        Log.multichainSwap.i("swap preparation started", extraInfo: routeInfo())
        try validate(route: route)
        let aggregator: MultichainSwapAggregator
        do {
            aggregator = try MultichainSwapAggregator(aggregator: route.aggregator)
        } catch {
            Log.multichainSwap.w(
                "swap preparation provider validation failed",
                error: error,
                extraInfo: routeInfo()
            )
            throw error
        }
        let preparedPayloads: [MultichainSwapPreparedPayload]
        var providerRouteId = route.providerRouteId
        if let inlinePayloads = route.payloads, !inlinePayloads.isEmpty {
            preparedPayloads = inlinePayloads
        } else {
            do {
                let prepare = try await swapService.prepareCrossSwapRoute(
                    routeId: route.routeId,
                    request: nil,
                    walletId: wallet.multichainWalletId
                )
                preparedPayloads = prepare.payloads
                providerRouteId = prepare.providerRouteId ?? providerRouteId
            } catch {
                Log.multichainSwap.w(
                    "swap preparation prepare failed",
                    error: error,
                    extraInfo: routeInfo()
                )
                throw SwapExecutionFailureMapper.failure(from: error)
            }
        }
        Log.multichainSwap.i(
            "swap preparation prepare completed",
            extraInfo: routeInfo([
                "payloadCount": "\(preparedPayloads.count)",
                "inlinePayloads": "\(route.payloads?.isEmpty == false)",
            ])
        )
        let payloads: MultichainSwapRoutePayloads
        let preparation: MultichainSwapPipelinePreparation
        do {
            payloads = try validatedPayloads(preparedPayloads, routeId: route.routeId)
            preparation = try await swapPipeline.prepareSwapPayloads(
                wallet: wallet,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                payloads: payloads,
                provider: aggregator.provider
            )
        } catch {
            Log.multichainSwap.w(
                "swap preparation pipeline failed",
                error: error,
                extraInfo: routeInfo()
            )
            throw error
        }
        let aggregated = Self.aggregatedFees(preparation.fees)
        let feeOptions = await feeMethodResolver.options(
            context: preparation.batteryPayload.map { batteryPayload in
                MultichainSwapFeeContext(
                    wallet: wallet,
                    sourceAsset: sourceAsset,
                    payloadId: payloads.main.payloadId,
                    requiresApproval: preparation.requiresApproval,
                    payload: batteryPayload
                )
            },
            nativeFees: aggregated,
            isNativeInsufficient: preparation.nativeFeeShortage != nil
        )
        // A relayed method the wallet is only short of charges or GRAM for is not a dead end: the
        // picker is the only place either can be bought, so the plan has to exist for the screen to
        // offer it at all. Only a swap left with the chain's own coin has nowhere else to go.
        let isFeePayable = feeOptions.contains { !$0.isInsufficient }
        let isRelayedFeeRefillable = feeOptions.contains { $0.method.isRelayed }
        if let nativeFeeShortage = preparation.nativeFeeShortage,
           !isFeePayable,
           !isRelayedFeeRefillable
        {
            let error = MultichainSwapExecutionFailure.insufficientNativeFee(shortage: nativeFeeShortage)
            Log.multichainSwap.w(
                "swap preparation failed: no fee method can pay",
                error: error,
                extraInfo: routeInfo(["feeMethods": Self.feeMethodIds(feeOptions)])
            )
            throw error
        }
        Log.multichainSwap.i(
            "swap preparation completed",
            extraInfo: routeInfo([
                "feeAssets": Self.feeAssetIds(aggregated),
                "payloadOrder": Self.payloadOrder(payloads.all),
                "feeMethods": Self.feeMethodIds(feeOptions),
            ])
        )
        return MultichainSwapExecutionPlan(
            routeId: route.routeId,
            aggregator: aggregator,
            providerRouteId: providerRouteId,
            payloads: payloads,
            networkFees: aggregated,
            requiresApproval: preparation.requiresApproval,
            feeOptions: feeOptions,
            payloadFees: preparation.payloadFees,
            batteryPayload: preparation.batteryPayload
        )
    }

    func execute(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        approvalMode: MultichainSwapApprovalMode,
        feeMethod: MultichainSwapFeeMethod
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
        func planInfo(_ additional: [String: String] = [:]) -> [String: String] {
            Self.executionPlanLogInfo(
                executionPlan: executionPlan,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                additional: additional
            )
        }
        Log.multichainSwap.i("execution started", extraInfo: planInfo())
        let payloads: MultichainSwapRoutePayloads
        do {
            payloads = try validatedPayloads(
                executionPlan.payloads.all,
                routeId: executionPlan.routeId
            )
        } catch {
            Log.multichainSwap.w(
                "execution payload validation failed",
                error: error,
                extraInfo: planInfo()
            )
            throw error
        }
        Log.multichainSwap.i(
            "payload validation completed",
            extraInfo: planInfo(["payloadOrder": Self.payloadOrder(payloads.all)])
        )

        switch feeMethod {
        case .battery, .gram:
            return try await executeWithRelayedFee(
                passcodeProvider: passcodeProvider,
                wallet: wallet,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                executionPlan: executionPlan,
                feeMethod: feeMethod
            )
        case .native:
            break
        }

        do {
            let broadcast = try await swapPipeline.executeSwapPayloads(
                passcodeProvider: passcodeProvider,
                wallet: wallet,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                payloads: payloads,
                payloadFees: executionPlan.payloadFees,
                provider: executionPlan.provider,
                approvalMode: approvalMode
            )
            let result = MultichainSwapExecutionResult(
                routeId: executionPlan.routeId,
                txHash: broadcast.txHash,
                broadcastedPayloads: broadcast.broadcastedPayloads
            )
            Log.multichainSwap.i(
                "execution completed after client broadcast",
                extraInfo: planInfo(["txHash": result.txHash])
            )
            await reportPendingTransaction(
                txHash: result.txHash,
                wallet: wallet,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                executionPlan: executionPlan
            )
            return result
        } catch {
            let executionFailure = error
            if case .canceled = executionFailure {
                Log.multichainSwap.i(
                    "execution cancelled",
                    error: executionFailure,
                    extraInfo: planInfo()
                )
                throw executionFailure
            }
            Log.multichainSwap.w(
                "execution client broadcast failed",
                error: executionFailure,
                extraInfo: planInfo()
            )
            throw executionFailure
        }
    }
}

extension MultichainSwapExecutionServiceImplementation {
    /// Sends the swap through the relayer instead of the chain's own broadcast. A relayed method that
    /// cannot be honoured fails the send rather than falling back: the user confirmed paying with it,
    /// and paying with something else is a different transaction.
    func executeWithRelayedFee(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        feeMethod: MultichainSwapFeeMethod
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
        func planInfo(_ additional: [String: String] = [:]) -> [String: String] {
            Self.executionPlanLogInfo(
                executionPlan: executionPlan,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                additional: additional
            )
        }
        guard let relayedSend = executionPlan.relayedSend(for: feeMethod),
              let engine = feeMethodResolver.engine(payload: relayedSend.payload)
        else {
            let error = MultichainSwapExecutionFailure.internal(
                reason: "no engine can pay for this swap with the selected fee method"
            )
            Log.multichainSwap.w(
                "execution rejected: unavailable fee method",
                error: error,
                extraInfo: planInfo()
            )
            throw error
        }
        let mainPayload = executionPlan.payloads.main
        let txHash = try await engine.send(
            context: MultichainSwapFeeContext(
                wallet: wallet,
                sourceAsset: sourceAsset,
                payloadId: mainPayload.payloadId,
                requiresApproval: executionPlan.requiresApproval,
                payload: relayedSend.payload
            ),
            confirmed: relayedSend.confirmed,
            passcodeProvider: passcodeProvider
        )
        let result = MultichainSwapExecutionResult(
            routeId: executionPlan.routeId,
            txHash: txHash,
            broadcastedPayloads: [
                MultichainSwapBroadcastedPayload(
                    payloadId: mainPayload.payloadId,
                    kind: mainPayload.kind,
                    payloadType: mainPayload.payloadType,
                    txHash: txHash
                ),
            ]
        )
        Log.multichainSwap.i(
            "execution completed after relay",
            extraInfo: planInfo(["txHash": txHash, "feeMethod": feeMethod.rawValue])
        )
        await reportPendingTransaction(
            txHash: txHash,
            wallet: wallet,
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            executionPlan: executionPlan
        )
        return result
    }

    func reportPendingTransaction(
        txHash: String,
        wallet: Wallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan
    ) async {
        guard let sourceChain = sourceAsset.asset.chain else {
            Log.multichainSwap.w(
                "pending transaction report skipped: unresolved source chain",
                extraInfo: [
                    "sourceAssetId": sourceAsset.asset.assetId,
                    "txHash": txHash,
                ]
            )
            return
        }
        guard let walletId = wallet.multichainWalletState?.walletId else {
            Log.multichainSwap.w(
                "pending transaction report skipped: wallet is not multichain",
                extraInfo: [
                    "sourceAssetId": sourceAsset.asset.assetId,
                    "txHash": txHash,
                ]
            )
            return
        }
        await pendingTransactionsService.report(
            MultichainPendingTransaction(
                walletId: walletId,
                chain: sourceChain,
                network: MultichainNetwork(walletNetwork: wallet.network),
                txHash: txHash,
                activityType: .swap(
                    MultichainPendingTransaction.SwapDetails(
                        fromAssetId: sourceAsset.asset.assetId,
                        toAssetId: destinationAsset.asset.assetId,
                        quote: .init(
                            aggregator: executionPlan.aggregator.rawValue,
                            routeId: executionPlan.routeId,
                            providerRouteId: executionPlan.providerRouteId
                        )
                    )
                )
            )
        )
    }

    func validate(route: MultichainSwapRoute) throws(MultichainSwapExecutionFailure) {
        guard route.dateExpire > now() else {
            let error = MultichainSwapExecutionFailure.routeExpired(routeId: route.routeId)
            Log.multichainSwap.w(
                "route validation failed: route expired",
                error: error,
                extraInfo: [
                    "routeId": route.routeId,
                    "dateExpire": "\(route.dateExpire)",
                ]
            )
            throw error
        }
    }

    func validatedPayloads(
        _ payloads: [MultichainSwapPreparedPayload],
        routeId: String
    ) throws(MultichainSwapExecutionFailure) -> MultichainSwapRoutePayloads {
        guard !payloads.isEmpty else {
            let error = MultichainSwapExecutionFailure.emptyPreparedPayloads(routeId: routeId)
            Log.multichainSwap.w(
                "payload validation failed: empty prepare result",
                error: error,
                extraInfo: ["routeId": routeId]
            )
            throw error
        }

        var main: MultichainSwapPreparedPayload?
        var approval: MultichainSwapPreparedPayload?
        for payload in payloads {
            guard payload.dateExpire > now() else {
                let error = MultichainSwapExecutionFailure.payloadExpired(payloadId: payload.payloadId)
                Log.multichainSwap.w(
                    "payload validation failed: payload expired",
                    error: error,
                    extraInfo: Self.payloadLogInfo(payload, routeId: routeId)
                )
                throw error
            }
            guard payload.payloadValidationStatus == .validated else {
                let error = MultichainSwapExecutionFailure.payloadNotValidated(
                    payloadId: payload.payloadId,
                    status: payload.validationStatus
                )
                Log.multichainSwap.w(
                    "payload validation failed: payload not validated",
                    error: error,
                    extraInfo: Self.payloadLogInfo(
                        payload,
                        routeId: routeId,
                        additional: ["validationStatus": payload.validationStatus]
                    )
                )
                throw error
            }
            switch payload.payloadKind {
            case .main:
                guard main == nil else {
                    let error = MultichainSwapExecutionFailure.invalidPayload(
                        payloadId: payload.payloadId,
                        reason: "swap route contains more than one main payload"
                    )
                    Log.multichainSwap.w(
                        "payload validation failed: duplicate main payload",
                        error: error,
                        extraInfo: Self.payloadLogInfo(payload, routeId: routeId)
                    )
                    throw error
                }
                main = payload
            case .approval:
                guard approval == nil else {
                    let error = MultichainSwapExecutionFailure.invalidPayload(
                        payloadId: payload.payloadId,
                        reason: "swap route contains more than one approval payload"
                    )
                    Log.multichainSwap.w(
                        "payload validation failed: duplicate approval payload",
                        error: error,
                        extraInfo: Self.payloadLogInfo(payload, routeId: routeId)
                    )
                    throw error
                }
                approval = payload
            case let .other(kind):
                let error = MultichainSwapExecutionFailure.invalidPayload(
                    payloadId: payload.payloadId,
                    reason: "unsupported payload kind \(kind)"
                )
                Log.multichainSwap.w(
                    "payload validation failed: unsupported payload kind",
                    error: error,
                    extraInfo: Self.payloadLogInfo(payload, routeId: routeId)
                )
                throw error
            }
        }
        guard let main else {
            let error = MultichainSwapExecutionFailure.missingMainPayload(routeId: routeId)
            Log.multichainSwap.w(
                "payload validation failed: missing main payload",
                error: error,
                extraInfo: ["routeId": routeId]
            )
            throw error
        }
        if let approval {
            return .approvalThenMain(approval: approval, main: main)
        }
        return .main(main)
    }

    static func aggregatedFees(
        _ fees: [MultichainTransactionEmulationResult]
    ) -> [MultichainTransactionEmulationResult] {
        var order = [String]()
        var totals = [String: BigUInt]()
        var assets = [String: MultichainAssetDetails]()

        for fee in fees {
            let assetId = fee.asset.assetId
            if totals[assetId] == nil {
                order.append(assetId)
                assets[assetId] = fee.asset
                totals[assetId] = 0
            }
            totals[assetId, default: 0] += fee.fee
        }

        return order.compactMap { assetId in
            guard let asset = assets[assetId],
                  let fee = totals[assetId]
            else {
                return nil
            }
            return MultichainTransactionEmulationResult(fee: fee, asset: asset)
        }
    }
}
