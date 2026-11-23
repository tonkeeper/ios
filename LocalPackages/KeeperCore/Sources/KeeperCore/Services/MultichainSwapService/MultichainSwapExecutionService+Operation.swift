@preconcurrency import BigInt
@preconcurrency import ChainKit
import Foundation
import OperationReviewModels
import SwapAPI
import TKLogging

extension MultichainSwapExecutionServiceImplementation {
    /// `route` as `/v3` prepares it: the backend's operation priced payload by payload, every fee in
    /// one asset; the coin has to cover a fee in it beside the coin the payloads send, unless a relayed
    /// method is offered for the operation, as `/v2` offers it for a route of its shape. The operation
    /// is signed as it was prepared, so nothing is trimmed to fit its fee.
    func operationPlan(
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        route: MultichainSwapRoute,
        aggregator: MultichainSwapAggregator
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan {
        func routeInfo(_ additional: [String: String] = [:]) -> [String: String] {
            Self.routeLogInfo(route: route, sourceAsset: sourceAsset, destinationAsset: destinationAsset, additional: additional)
        }
        let prepared: MultichainSwapPreparedOperation
        do {
            prepared = try await prepare(route, swapWallet: swapWallet)
        } catch {
            Log.multichainSwap.w("swap operation preparation failed", error: error, extraInfo: routeInfo())
            throw error
        }
        let operation = prepared.operation
        guard let chain = sourceAsset.asset.chain else {
            throw .internal(reason: "the asset sold names no chain: \(sourceAsset.asset.assetId)")
        }
        guard let address = swapWallet.walletAddress(for: chain) else {
            throw .missingWalletAddress(chain: chain)
        }
        let account: ChainKit.Account
        let coinAccount: ChainKit.Account
        do {
            account = try ChainKitOperationSender.account(of: address, holding: sourceAsset.asset)
            coinAccount = try ChainKitOperationSender.account(of: address, asset: nil)
        } catch {
            throw .internal(reason: "the swap's account cannot be built: \(error.logDescription)")
        }
        let signingAccount = chain == .sol ? account : coinAccount
        guard operation.payloads.allSatisfy({ $0.chain.caip2 == signingAccount.chain.caip2 }) else {
            throw .preparationFailed(kind: .unsupportedTransaction, reason: "the operation signs on another chain than the asset sold")
        }
        let (fees, pricingFailure) = try await price(operation, from: signingAccount, isEVM: chain.isEVM)
        guard let feeAsset = fees.first?.asset, let swapPayload = operation.payloads.last, fees.allSatisfy({ $0.asset.id == feeAsset.id }) else {
            throw pricingFailure ?? .preparationFailed(kind: .unsupportedTransaction, reason: "the operation's fees are paid in more than one asset")
        }
        let fee = SwapFeeResolver().combinedFee(fees, asset: feeAsset)
        guard let feeUnits = BigUInt(fee.amount.description) else {
            throw .internal(reason: "fee amount value is not a number: \(fee.amount.description)")
        }
        let feeDetails = await operationSteps.details(of: feeAsset, wallet: swapWallet.wallet)
        var nativeFeeShortage: MultichainNativeFeeShortage?
        if feeAsset.id == coinAccount.asset.id {
            let isCovered: Bool
            do {
                isCovered = try await operationSteps.covers(operation.coinValue, and: fee, from: coinAccount)
            } catch {
                throw pricingFailure ?? error
            }
            if !isCovered {
                // The swap screen holds the amount sold to the balance: the shortage is the fee and
                // the coin the payloads send beside that amount, what a token sale's transfer carries
                // or the gas a TON swap forwards.
                let sold = account.asset.id == coinAccount.asset.id ? route.quotedSourceAmount ?? 0 : 0
                guard let sent = BigUInt(operation.coinValue.description) else {
                    throw .internal(reason: "the coin the swap sends is not a number: \(operation.coinValue.description)")
                }
                nativeFeeShortage = MultichainNativeFeeShortage(asset: feeDetails, requiredAmount: feeUnits + (sent > sold ? sent - sold : 0))
            }
        }
        if nativeFeeShortage == nil, let pricingFailure {
            Log.multichainSwap.w("swap operation preparation failed: a payload could not be priced", error: pricingFailure, extraInfo: routeInfo())
            throw pricingFailure
        }
        let networkFees = [MultichainTransactionEmulationResult(fee: feeUnits, asset: feeDetails)]
        let requiresApproval = operation.payloads.count > 1
        let batteryPayload = MultichainSwapBatteryPayload(relaying: operation, selling: sourceAsset, from: address.address)
        let spentSourceAmount = route.spentSourceAmount(sourceAsset: sourceAsset)
        let feeOptions = await feeMethodResolver.options(
            context: batteryPayload.map { batteryPayload in
                MultichainSwapFeeContext(
                    swapWallet: swapWallet,
                    sourceAsset: sourceAsset,
                    payloadId: swapPayload.id,
                    requiresApproval: requiresApproval,
                    payload: batteryPayload,
                    spentSourceAmount: spentSourceAmount
                )
            },
            nativeFees: networkFees,
            isNativeInsufficient: nativeFeeShortage != nil
        )
        if let nativeFeeShortage, Self.isDeadEnd(feeOptions) {
            let shortage = MultichainSwapExecutionFailure.insufficientNativeFee(shortage: nativeFeeShortage)
            Log.multichainSwap.w(
                "swap operation preparation failed: the coin cannot pay",
                error: shortage,
                extraInfo: routeInfo(pricingFailure.map { ["pricingFailure": $0.logDescription] } ?? [:])
            )
            throw shortage
        }
        if let pricingFailure {
            Log.multichainSwap.w(
                "swap operation pricing failed on a wallet short of the coin",
                error: pricingFailure,
                extraInfo: routeInfo(["feeMethods": Self.feeMethodIds(feeOptions)])
            )
        }
        Log.multichainSwap.i(
            "swap operation preparation completed",
            extraInfo: routeInfo([
                "payloadOrder": operation.payloads.map(\.id).joined(separator: ","),
                "feeAssets": feeAsset.id,
                "feeMethods": Self.feeMethodIds(feeOptions),
            ])
        )
        return MultichainSwapExecutionPlan(
            routeId: route.routeId,
            aggregator: aggregator,
            providerRouteId: prepared.providerRouteId ?? route.providerRouteId,
            signs: .operation(
                MultichainSwapOperation(
                    operation: operation,
                    account: account,
                    signingAccount: signingAccount,
                    fees: fees,
                    recipient: prepared.depositAddress ?? operation.calledContract,
                    expiresAt: prepared.expiresAt.addingTimeInterval(-MultichainSwapOperation.expiryLead),
                    route: route.prepared(as: prepared)
                )
            ),
            networkFees: networkFees,
            requiresApproval: requiresApproval,
            feeOptions: feeOptions,
            batteryPayload: batteryPayload,
            spentSourceAmount: spentSourceAmount,
            sourceAmount: route.sourceAmount,
            nativeFeeShortage: nativeFeeShortage
        )
    }

    /// Reviews the operation before the passcode, so one the gate refuses is never unlocked for, then
    /// signs it at the fees its plan priced and sends it. Once the passcode released it, closing the
    /// screen no longer stops it, as it does not stop a send. A relayed method sends it the way `/v2`
    /// relays a route, held to the deadline of the operation.
    func executeOperation(
        _ swap: MultichainSwapOperation,
        signer: MultichainTransferSigner,
        swapWallet: MultichainSwapWallet,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        executionPlan: MultichainSwapExecutionPlan,
        feeMethod: MultichainSwapFeeMethod,
        spendLimit: BigUInt,
        consent: OperationConsent
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
        func planInfo(_ additional: [String: String] = [:]) -> [String: String] {
            Self.executionPlanLogInfo(executionPlan: executionPlan, sourceAsset: sourceAsset, destinationAsset: destinationAsset, additional: additional)
        }
        guard case let .mnemonic(passcodeProvider) = signer, swapWallet.keys == .hd, let swapPayload = swap.operation.payloads.last else {
            let error = MultichainSwapExecutionFailure.internal(reason: "a route prepared on /v3 is signed with the wallet's mnemonic")
            Log.multichainSwap.w("execution rejected: a /v3 route it cannot sign", error: error, extraInfo: planInfo())
            throw error
        }
        try checkLive(swap, routeId: executionPlan.routeId)
        switch feeMethod {
        case .battery, .gram, .token:
            // The engine asks for the passcode as it sends, and the passcode can outlast the route:
            // once it has, the engine is handed none, and signs nothing.
            let lapse = PasscodeLapse()
            let signer = MultichainTransferSigner.mnemonic { [now] in
                guard let passcode = await passcodeProvider() else {
                    return nil
                }
                guard swap.expiresAt > now() else {
                    await lapse.record()
                    return nil
                }
                return passcode
            }
            do {
                return try await executeWithRelayedFee(
                    signer: signer,
                    swapWallet: swapWallet,
                    sourceAsset: sourceAsset,
                    destinationAsset: destinationAsset,
                    executionPlan: executionPlan,
                    relayed: RelayedPayload(id: swapPayload.id, type: swapPayload.type.id, expiresAt: swap.expiresAt, isHeldBeforeTheReview: true),
                    feeMethod: feeMethod,
                    spendLimit: spendLimit,
                    consent: consent
                )
            } catch .canceled {
                if await lapse.hasLapsed {
                    try checkLive(swap, routeId: executionPlan.routeId)
                }
                throw .canceled
            }
        case .native:
            break
        }
        // Signed as `/prepare` built it, the operation names no recipient: the addresses its route pays
        // come from the same answer, so holding it to them checks nothing, while one read wrong warns
        // of a danger that is not there. The amount sold still bounds it.
        do throws(OperationRefusal) {
            try await gate.clear(.ask, consent: consent) {
                [
                    SignableOperation(
                        operation: swap.operation,
                        account: swap.account,
                        intent: .send(spendLimit, of: sourceAsset.asset, to: nil),
                        fidelity: .exact
                    ),
                ]
            }
        } catch .declined {
            Log.multichainSwap.i("execution declined in review", extraInfo: planInfo())
            throw .canceled
        } catch {
            let failure = MultichainSwapExecutionFailure.internal(reason: "the swap could not be reviewed: \(error)")
            Log.multichainSwap.w("execution rejected: unreviewable swap operation", error: failure, extraInfo: planInfo())
            throw failure
        }
        let wallet = try await operationSteps.unlock(passcodeProvider: passcodeProvider, swapWallet: swapWallet)
        // The passcode can outlast the route.
        try checkLive(swap, routeId: executionPlan.routeId)
        let account: ChainKit.Account
        do {
            account = try ChainKitOperationSender.account(swap.signingAccount, signedBy: wallet)
        } catch {
            throw .internal(reason: "the swap operation is not the unlocked wallet's to sign: \(error.logDescription)")
        }
        let sending = Task { [operationSteps] () async -> Result<[String], MultichainSwapExecutionFailure> in
            do throws(MultichainSwapExecutionFailure) {
                return try await .success(operationSteps.send(swap.operation, account: account, wallet: wallet, expiresAt: swap.expiresAt, fees: swap.fees))
            } catch {
                return .failure(error)
            }
        }
        let hashes: [String]
        do {
            hashes = try await sending.value.get()
        } catch {
            Log.multichainSwap.w("execution of the swap operation failed", error: error, extraInfo: planInfo())
            throw error
        }
        let payloads = swap.operation.payloads
        guard hashes.count == payloads.count, let txHash = hashes.last else {
            throw .internal(reason: "the swap operation was sent as \(hashes.count) of its \(payloads.count) payloads")
        }
        Log.multichainSwap.i("execution completed after client broadcast", extraInfo: planInfo(["txHash": txHash]))
        await reportPendingTransaction(
            txHash: txHash,
            swapWallet: swapWallet,
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            executionPlan: executionPlan
        )
        return MultichainSwapExecutionResult(
            routeId: executionPlan.routeId,
            txHash: txHash,
            broadcastedPayloads: zip(payloads, hashes).enumerated().map { index, sent in
                MultichainSwapBroadcastedPayload(
                    payloadId: sent.0.id,
                    kind: index == payloads.count - 1 ? "main" : "approval",
                    payloadType: sent.0.type.id,
                    txHash: sent.1
                )
            }
        )
    }
}

private extension MultichainSwapExecutionServiceImplementation {
    /// One fee per payload, in its order: the backend's where it quotes one, else chain-kit's price.
    /// A swap behind its approve spends an allowance not yet granted, and simulated it reverts: on
    /// EVM it takes the chain's default fee. A chain that prices a payload by emulating it cannot
    /// price one the wallet has no coin to send, and the failure often arrives untyped: such a payload
    /// is put to the balance at the chain's default fee, or at the coin it sends alone where chain-kit
    /// has none for it, and its failure stands unless the balance falls short.
    func price(
        _ operation: ChainKit.Operation,
        from account: ChainKit.Account,
        isEVM: Bool
    ) async throws(MultichainSwapExecutionFailure) -> (fees: [any Fee], failure: MultichainSwapExecutionFailure?) {
        var fees = [any Fee]()
        var failure: MultichainSwapExecutionFailure?
        for (index, payload) in operation.payloads.enumerated() {
            if index > 0, payload.fee == nil, isEVM {
                try await fees.append(operationSteps.defaultFee(of: payload, account: account))
                continue
            }
            do {
                try await fees.append(operationSteps.fee(of: payload, account: account))
            } catch {
                failure = failure ?? error
                do {
                    try await fees.append(operationSteps.defaultFee(of: payload, account: account))
                } catch {
                    Log.multichainSwap.i(
                        "swap operation payload has no default fee: put to the balance at the coin it sends",
                        error: error,
                        extraInfo: ["operation": operation.id, "payload": payload.id]
                    )
                    fees.append(FeeValue(asset: account.chain.toAsset(), amount: BignumBigInteger.Companion.shared.ZERO))
                }
            }
        }
        return (fees, failure)
    }

    /// The route's operation, as `/v3` builds it for the wallet. One still being validated may pass on
    /// a fresh route; one rejected, or one chain-kit cannot read, is no route to swap.
    func prepare(
        _ route: MultichainSwapRoute,
        swapWallet: MultichainSwapWallet
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPreparedOperation {
        guard let walletId = swapWallet.walletId else {
            throw .internal(reason: "a route quoted on /v3 is prepared for a registered wallet only")
        }
        let response: SwapAPI.Components.Schemas.CrossSwapPrepareV3
        do {
            response = try await swapAPI.prepareCrossSwapRouteV3(routeId: route.routeId, walletId: walletId)
        } catch {
            throw SwapExecutionFailureMapper.failure(from: error)
        }
        let prepared: MultichainSwapPreparedOperation
        do {
            prepared = try MultichainSwapPreparedOperation(response)
        } catch .pending {
            throw .payloadNotValidated(payloadId: route.routeId, status: "pending")
        } catch {
            throw .preparationFailed(kind: .unsupportedTransaction, reason: "the route prepared on /v3 cannot be swapped: \(error)")
        }
        guard prepared.routeId == route.routeId else {
            throw .preparationFailed(kind: .badResponse, reason: "/v3 prepared route \(prepared.routeId) for route \(route.routeId)")
        }
        return prepared
    }

    func checkLive(_ swap: MultichainSwapOperation, routeId: String) throws(MultichainSwapExecutionFailure) {
        guard swap.expiresAt > now() else {
            let error = MultichainSwapExecutionFailure.routeExpired(routeId: routeId)
            Log.multichainSwap.w("execution rejected: the swap operation expired", error: error, extraInfo: ["routeId": routeId])
            throw error
        }
    }
}

/// Whether a relayed swap's passcode came back past the operation's deadline and was withheld from its
/// engine: the swap then stopped for the route, not for the user.
private actor PasscodeLapse {
    private(set) var hasLapsed = false

    func record() {
        hasLapsed = true
    }
}
