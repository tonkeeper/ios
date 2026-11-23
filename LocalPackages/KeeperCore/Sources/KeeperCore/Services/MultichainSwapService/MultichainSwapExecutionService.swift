import BigInt
import ChainKit
import Foundation
import OperationReviewModels
import TKLogging

public protocol MultichainSwapExecutionService {
    func prepareExecutionPlan(
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        route: MultichainSwapRoute
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan

    /// `spendLimit` is the most of `sourceAsset` the user agreed to sell, in its base units, and
    /// `consent` answers what the review of a relayed swap asks. The chain's own coin uses neither.
    func execute(
        signer: MultichainTransferSigner,
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        feeMethod: MultichainSwapFeeMethod,
        spendLimit: BigUInt,
        consent: OperationConsent
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult
}

final class MultichainSwapExecutionServiceImplementation: MultichainSwapExecutionService {
    private let swapService: MultichainSwapService
    let swapAPI: MultichainSwapAPI
    private let swapPipeline: ChainKitSwapPipeline
    let operationSteps: MultichainSwapOperationSteps
    private let pendingTransactionsService: PendingTransactionsService
    let feeMethodResolver: MultichainSwapFeeMethodResolver
    let gate: OperationGate
    let now: () -> Date
    private let batteryPaymentPreparation: BatteryPaymentPreparation

    init(
        swapService: MultichainSwapService,
        swapAPI: MultichainSwapAPI,
        swapPipeline: ChainKitSwapPipeline,
        operationSteps: MultichainSwapOperationSteps,
        pendingTransactionsService: PendingTransactionsService,
        feeMethodResolver: MultichainSwapFeeMethodResolver,
        gate: OperationGate,
        now: @escaping () -> Date = Date.init,
        batteryPaymentPreparation: BatteryPaymentPreparation = BatteryPaymentPreparation()
    ) {
        self.swapService = swapService
        self.swapAPI = swapAPI
        self.swapPipeline = swapPipeline
        self.operationSteps = operationSteps
        self.pendingTransactionsService = pendingTransactionsService
        self.feeMethodResolver = feeMethodResolver
        self.gate = gate
        self.now = now
        self.batteryPaymentPreparation = batteryPaymentPreparation
    }

    func prepareExecutionPlan(
        swapWallet: MultichainSwapWallet,
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
        if route.apiVersion == .v3 {
            return try await operationPlan(
                swapWallet: swapWallet,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                route: route,
                aggregator: aggregator
            )
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
                    walletId: swapWallet.walletId
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
                swapWallet: swapWallet,
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
        let spentSourceAmount = route.spentSourceAmount(sourceAsset: sourceAsset)
        let feeOptions = await feeMethodResolver.options(
            context: preparation.batteryPayload.map { batteryPayload in
                MultichainSwapFeeContext(
                    swapWallet: swapWallet,
                    sourceAsset: sourceAsset,
                    payloadId: payloads.main.payloadId,
                    requiresApproval: preparation.requiresApproval,
                    payload: batteryPayload,
                    spentSourceAmount: spentSourceAmount
                )
            },
            nativeFees: aggregated,
            isNativeInsufficient: preparation.nativeFeeShortage != nil
        )
        if let nativeFeeShortage = preparation.nativeFeeShortage, Self.isDeadEnd(feeOptions) {
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
            batteryPayload: preparation.batteryPayload,
            spentSourceAmount: spentSourceAmount,
            sourceAmount: route.sourceAmount
        )
    }

    func execute(
        signer originalSigner: MultichainTransferSigner,
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        feeMethod: MultichainSwapFeeMethod,
        spendLimit: BigUInt,
        consent: OperationConsent
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
        let signer: MultichainTransferSigner
        do {
            let requiredCharges: Int?
            if case let .batteryCharges(count, _, _) = executionPlan.feeOptions.first(where: { $0.method == feeMethod })?.cost {
                requiredCharges = count
            } else {
                requiredCharges = nil
            }
            let prepared = feeMethod.isBattery
                ? try await batteryPaymentPreparation.prepare(wallet: swapWallet.wallet, signer: originalSigner, requiredCharges: requiredCharges)
                : nil
            signer = prepared?.signer ?? originalSigner
        } catch is CancellationError {
            throw .canceled
        } catch {
            Log.multichainSwap.w("battery migration failed before swap", error: error)
            throw .preparationFailed(kind: .networkError, reason: error.logDescription)
        }
        func planInfo(_ additional: [String: String] = [:]) -> [String: String] {
            Self.executionPlanLogInfo(
                executionPlan: executionPlan,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                additional: additional
            )
        }
        Log.multichainSwap.i("execution started", extraInfo: planInfo())
        let routePayloads: MultichainSwapRoutePayloads
        switch executionPlan.signs {
        case let .payloads(signed):
            routePayloads = signed
        case let .operation(operation):
            return try await executeOperation(
                operation,
                signer: signer,
                swapWallet: swapWallet,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                executionPlan: executionPlan,
                feeMethod: feeMethod,
                spendLimit: spendLimit,
                consent: consent
            )
        }
        let payloads: MultichainSwapRoutePayloads
        do {
            payloads = try validatedPayloads(
                routePayloads.all,
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
        case .battery, .gram, .token:
            return try await executeWithRelayedFee(
                signer: signer,
                swapWallet: swapWallet,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                executionPlan: executionPlan,
                relayed: RelayedPayload(
                    id: payloads.main.payloadId,
                    type: payloads.main.payloadType,
                    expiresAt: payloads.main.dateExpire,
                    isHeldBeforeTheReview: false
                ),
                feeMethod: feeMethod,
                spendLimit: spendLimit,
                consent: consent
            )
        case .native:
            break
        }

        do {
            let broadcast = try await swapPipeline.executeSwapPayloads(
                signer: signer,
                swapWallet: swapWallet,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                payloads: payloads,
                payloadFees: executionPlan.payloadFees,
                provider: executionPlan.provider
            )
            let result = MultichainSwapExecutionResult(
                routeId: executionPlan.routeId,
                txHash: broadcast.txHash,
                broadcastedPayloads: broadcast.broadcastedPayloads
            )
            Log.multichainSwap.i(
                "execution completed after client broadcast",
                extraInfo: planInfo(["txHash": broadcast.txHash])
            )
            await reportPendingTransaction(
                txHash: broadcast.txHash,
                swapWallet: swapWallet,
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
    /// The payload of a swap its relayer carries, as the swap's result names it, and the deadline
    /// nothing of it is relayed past.
    struct RelayedPayload {
        let id: String
        let type: String
        let expiresAt: Date
        /// `/v3` found its operation's deadline live a moment before the engine prepared it, so a lapse
        /// since is the route's: it stops the swap before the review. `/v2` leaves one its engine
        /// prepared past to the relayer.
        let isHeldBeforeTheReview: Bool
    }

    /// A relayed method the wallet is only short of charges or GRAM for is not a dead end: the
    /// picker is the only place either can be bought, so the plan has to exist for the screen to
    /// offer it at all. Only a swap left with the chain's own coin has nowhere else to go.
    static func isDeadEnd(_ feeOptions: [MultichainSwapFeeOption]) -> Bool {
        !feeOptions.contains { !$0.isInsufficient || $0.method.isRelayed }
    }

    /// Sends the swap through the relayer instead of the chain's own broadcast. A relayed method that
    /// cannot be honoured fails the send rather than falling back: the user confirmed paying with it,
    /// and paying with something else is a different transaction. What the engine prepared is
    /// reviewed, held to `spendLimit` of the source asset, to a token fee and to the address its route
    /// runs through: before it is signed when the review asks, beside its signature when it only logs.
    func executeWithRelayedFee(
        signer: MultichainTransferSigner,
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        relayed: RelayedPayload,
        feeMethod: MultichainSwapFeeMethod,
        spendLimit: BigUInt,
        consent: OperationConsent
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
        let prepared = try await engine.prepare(
            context: MultichainSwapFeeContext(
                swapWallet: swapWallet,
                sourceAsset: sourceAsset,
                payloadId: relayed.id,
                requiresApproval: executionPlan.requiresApproval,
                payload: relayedSend.payload,
                spentSourceAmount: executionPlan.spentSourceAmount
            ),
            confirmed: relayedSend.confirmed
        )
        // The user can read the review past either deadline, so one that was live before it must
        // still be live after it. One the device's clock had passed already is the relayer's to
        // judge: a clock running ahead must not fail every reviewed swap.
        let payloadWasLive = relayed.expiresAt > now()
        let relayWasLive = !prepared.isExpired(at: now())
        guard payloadWasLive || !relayed.isHeldBeforeTheReview else {
            let error = MultichainSwapExecutionFailure.payloadExpired(payloadId: relayed.id)
            Log.multichainSwap.w("execution rejected: relayed swap expired while it was prepared", error: error, extraInfo: planInfo())
            throw error
        }
        do throws(OperationRefusal) {
            try await gate.clear(relayedSend.presentation, consent: consent) {
                try await prepared.signables(.send(spendLimit, of: sourceAsset.asset, to: relayedSend.recipient, fee: relayedSend.tokenFee))
            }
        } catch .declined {
            Log.multichainSwap.i("execution declined in review", extraInfo: planInfo())
            throw .canceled
        } catch {
            let failure = MultichainSwapExecutionFailure.internal(reason: "the relayed swap could not be reviewed: \(error)")
            Log.multichainSwap.w("execution rejected: unreviewable relayed swap", error: failure, extraInfo: planInfo())
            throw failure
        }
        let payloadLapsed = payloadWasLive && relayed.expiresAt <= now()
        let relayLapsed = relayWasLive && prepared.isExpired(at: now())
        guard !payloadLapsed, !relayLapsed else {
            let error = MultichainSwapExecutionFailure.payloadExpired(payloadId: relayed.id)
            Log.multichainSwap.w("execution rejected: relayed swap expired while it was reviewed", error: error, extraInfo: planInfo())
            throw error
        }
        guard !Task.isCancelled else { throw .canceled }
        let txHash = try await prepared.send(signer)
        let result = MultichainSwapExecutionResult(
            routeId: executionPlan.routeId,
            txHash: txHash,
            broadcastedPayloads: txHash.map { txHash in
                [
                    MultichainSwapBroadcastedPayload(
                        payloadId: relayed.id,
                        kind: "main",
                        payloadType: relayed.type,
                        txHash: txHash
                    ),
                ]
            } ?? []
        )
        Log.multichainSwap.i(
            "execution completed after relay",
            extraInfo: planInfo(["txHash": txHash ?? "none", "feeMethod": feeMethod.id])
        )
        // A relayer that names no transaction leaves nothing to report: the swap reaches the
        // history once the relayer's own transaction does.
        if let txHash {
            await reportPendingTransaction(
                txHash: txHash,
                swapWallet: swapWallet,
                sourceAsset: sourceAsset,
                destinationAsset: destinationAsset,
                executionPlan: executionPlan
            )
        }
        return result
    }

    func reportPendingTransaction(
        txHash: String,
        swapWallet: MultichainSwapWallet,
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
        guard let walletId = swapWallet.walletId else {
            Log.multichainSwap.w(
                "pending transaction report skipped: wallet is not registered",
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
                network: MultichainNetwork(walletNetwork: swapWallet.wallet.network),
                txHash: txHash,
                activityType: .swap(
                    MultichainPendingTransaction.SwapDetails(
                        fromAssetId: sourceAsset.asset.assetId,
                        toAssetId: destinationAsset.asset.assetId,
                        fromAddress: swapWallet.address(for: sourceChain),
                        fromAmount: executionPlan.sourceAmount,
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
