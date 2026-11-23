import BigInt
import Foundation
import OperationReviewModels
import TKLogging

/// Prices and sends an EVM or Solana transfer through the battery's relayer, which pays the chain and
/// takes its fee in battery charges or in a token of the chain. The chain's own coin stays with ChainKit:
/// this engine only puts the relayed methods next to it.
final class EVMGaslessFeeEngine {
    struct Transfer {
        let wallet: Wallet
        let chain: MultichainChain
        /// The asset being sent, with the balance the fee is weighed against.
        let asset: MultichainAsset
        let amount: BigUInt
        let recipient: String
        let comment: String?
    }

    /// The fee methods of a transfer as priced so far: estimates for every method, and the
    /// relayer's emulation of the one that holds the selection.
    struct Quote {
        let call: EVMGaslessCall
        var options: [EVMGaslessFeeOption]
        var emulation: EVMGaslessEmulation?
        /// What the checks found in the operation `emulation` holds for the selection.
        var review: OperationReview?
        var heldFeeType: TransactionConfirmationModel.ExtraType? = nil
        var unaffordablePick: EVMGaslessFeeOption?

        func selected(picked: TransactionConfirmationModel.ExtraType?) -> EVMGaslessFeeOption? {
            if let heldFeeType { return options.first { $0.isNamed(by: heldFeeType) } }
            return EVMGaslessFeeSelection.resolve(options, picked: unaffordablePick?.isNamed(by: picked) == true ? nil : picked)
        }
    }

    private let relayer: EVMGaslessRelaying
    private let signer: MultichainRelayedOperationSigner
    /// The remote battery switches; the wallet's own are read here.
    private let isEnabled: (Wallet) async -> Bool
    private let batteryCharges: (Wallet) async -> BatteryChargesAvailability
    private let currentBatteryCharges: (Wallet) async -> BatteryChargesAvailability
    private let offersBatteryMigration: (Wallet) async -> Bool
    /// The wallet's own entries for assets other than the one being sent, by the ids they are asked
    /// for; an asset the wallet does not list, or whose listing cannot be read, is missing from the answer.
    private let walletTokens: (_ assetIds: [String], _ wallet: Wallet) async -> [String: MultichainAsset]
    private let gate: OperationGate
    private let now: () -> Date

    init(
        relayer: EVMGaslessRelaying,
        signer: MultichainRelayedOperationSigner,
        isEnabled: @escaping (Wallet) async -> Bool,
        batteryCharges: @escaping (Wallet) async -> BatteryChargesAvailability,
        walletTokens: @escaping (_ assetIds: [String], _ wallet: Wallet) async -> [String: MultichainAsset],
        gate: OperationGate,
        now: @escaping () -> Date = Date.init,
        currentBatteryCharges: ((Wallet) async -> BatteryChargesAvailability)? = nil,
        offersBatteryMigration: @escaping (Wallet) async -> Bool = { _ in false }
    ) {
        self.relayer = relayer
        self.signer = signer
        self.isEnabled = isEnabled
        self.batteryCharges = batteryCharges
        self.currentBatteryCharges = currentBatteryCharges ?? batteryCharges
        self.offersBatteryMigration = offersBatteryMigration
        self.walletTokens = walletTokens
        self.gate = gate
        self.now = now
    }

    /// The relayed methods the relayer offers for `transfer`, or nil when it offers none: the
    /// transfer then stays with the wallet paying, exactly as without a relayer.
    func estimate(_ transfer: Transfer) async -> Quote? {
        guard Self.isRelayAllowed(by: transfer.wallet),
              await isEnabled(transfer.wallet),
              let sender = transfer.wallet.multichainAddress(for: transfer.chain),
              let call = EVMGaslessCall.transfer(
                  chain: transfer.chain,
                  sender: sender,
                  assetId: transfer.asset.asset.assetId,
                  recipient: transfer.recipient,
                  amount: transfer.amount,
                  memo: transfer.comment
              )
        else {
            return nil
        }
        let estimations: [EVMGaslessEstimation]
        do {
            estimations = try await relayer.estimate(wallet: transfer.wallet, call: call)
        } catch {
            Log.multichain.w(
                "gasless estimate failed, the transfer keeps the chain fee",
                error: error,
                extraInfo: ["assetId": transfer.asset.asset.assetId]
            )
            return nil
        }
        let migrationPending = await offersBatteryMigration(transfer.wallet)
        let options = await reweighed(
            estimations.compactMap { option(for: $0, transfer: transfer, migrationPending: migrationPending) },
            transfer: transfer
        )
        guard !options.isEmpty else {
            return nil
        }
        return Quote(call: call, options: options, emulation: nil)
    }

    /// Prices the method that holds the selection for real. A relayed method is only an estimate
    /// until the relayer emulates it, and an emulation can rule it out — the selection then moves
    /// on and the next method is emulated in its turn.
    func quote(
        _ quote: Quote,
        picked: TransactionConfirmationModel.ExtraType?,
        transfer: Transfer
    ) async -> Quote {
        var current = quote
        current.options = EVMGaslessFeeSelection.prioritize(
            current.options,
            sentAssetId: transfer.asset.asset.assetId
        )
        for _ in current.options.indices {
            guard let selected = current.selected(picked: picked),
                  selected.isRelayed,
                  selected.canPay,
                  let assetId = selected.relayerAssetId
            else {
                break
            }
            if selected.isBattery, await offersBatteryMigration(transfer.wallet) {
                current.emulation = nil
                break
            }
            if let emulation = current.emulation, emulation.assetId == assetId, !emulation.isExpired(at: now()) {
                break
            }
            current.emulation = nil
            do {
                let emulation = try await relayer.emulate(wallet: transfer.wallet, call: current.call, assetId: assetId)
                if let refusal = Self.refusal(of: emulation, call: current.call, chain: transfer.chain, paidWith: selected, now: now()) {
                    Log.multichain.w(
                        "gasless emulation ruled the fee method out: the relayer built another operation",
                        extraInfo: ["assetId": transfer.asset.asset.assetId, "feeAssetId": assetId, "reason": refusal]
                    )
                    current.options = EVMGaslessFeeSelection.rulingOut(selected, in: current.options)
                    continue
                }
                var priced = selected.priced(emulation.fee)
                priced.isInsufficient = await isInsufficient(priced, transfer: transfer)
                guard priced.canPay else {
                    current.options = EVMGaslessFeeSelection.payableFirst(EVMGaslessFeeSelection.replacing(priced, in: current.options))
                    if priced.isNamed(by: picked) { current.unaffordablePick = priced }
                    continue
                }
                current.options = EVMGaslessFeeSelection.replacing(priced, in: current.options)
                current.emulation = emulation
                break
            } catch {
                Log.multichain.w(
                    "gasless emulation ruled the fee method out",
                    error: error,
                    extraInfo: ["assetId": transfer.asset.asset.assetId, "feeAssetId": assetId]
                )
                current.options = EVMGaslessFeeSelection.rulingOut(selected, in: current.options)
            }
        }
        current.review = nil
        if let emulation = current.emulation,
           let selected = current.selected(picked: picked),
           selected.relayerAssetId == emulation.assetId
        {
            current.review = await gate.preview(Self.presentation(of: selected, on: transfer.chain)) {
                try [Self.signable(of: emulation, paidWith: selected, transfer: transfer)]
            }
        }
        return current
    }

    /// `options` weighed again against the balances as they are now, which can have moved since the
    /// quote was made.
    func reweighed(_ options: [EVMGaslessFeeOption], transfer: Transfer) async -> [EVMGaslessFeeOption] {
        let heldTokens = await loadWalletTokens(weighing: options, transfer: transfer)
        var reweighed = options
        for index in reweighed.indices {
            reweighed[index].isInsufficient = await isInsufficient(reweighed[index], transfer: transfer, heldTokens: heldTokens)
            // A token the wallet lists goes by the wallet's entry for it, as the sent one does: the
            // pick and the deposit need the wallet's id, the relayer keeps its own in `relayerAssetId`.
            if case let .token(asset, fee) = reweighed[index].payer, let held = heldTokens[asset.assetId] {
                reweighed[index].payer = .token(held.asset, fee: fee)
            }
        }
        return reweighed
    }

    /// Sends the transfer through the relayer, paying with `selected`; `consent` answers what the
    /// review of the operation signed asks. Returns the relayer's transaction hash when it gives one.
    func send(
        _ quote: Quote,
        selected: EVMGaslessFeeOption,
        transfer: Transfer,
        passcodeProvider: @escaping () async -> String?,
        consent: OperationConsent
    ) async -> Result<String?, TransactionConfirmationError> {
        guard let assetId = selected.relayerAssetId else {
            return .failure(.multichainTransactionFailure(.internal(reason: "the chain's coin is not relayed")))
        }
        // A Solana operation carries a recent blockhash that lapses well before the relayer's deadline:
        // every send builds it again, after the PIN, whose wait can outlast the blockhash too.
        let rebuildsOnSend = transfer.chain == .sol
        let signingPasscodeProvider: () async -> String?
        if rebuildsOnSend {
            guard let passcode = await passcodeProvider(), !Task.isCancelled else {
                return .failure(.cancelledByUser)
            }
            signingPasscodeProvider = { passcode }
        } else {
            signingPasscodeProvider = passcodeProvider
        }

        // The quote can be minutes old by the time the user confirms: price the chosen method again
        // rather than ask the relayer to broadcast an operation it has already forgotten.
        let emulation: EVMGaslessEmulation
        if let quoted = quote.emulation, quoted.assetId == assetId, !rebuildsOnSend, !quoted.isExpired(at: now()) {
            emulation = quoted
        } else {
            do {
                emulation = try await relayer.emulate(wallet: transfer.wallet, call: quote.call, assetId: assetId)
            } catch {
                Log.multichain.e(
                    "gasless emulation failed before sending",
                    error: error,
                    extraInfo: ["assetId": transfer.asset.asset.assetId, "feeAssetId": assetId]
                )
                return .failure(.multichainTransactionFailure(.relayerQuoteUnavailable(reason: error.logDescription)))
            }
            do {
                try Self.requireConfirmedFee(emulation.fee, of: selected, operationId: emulation.operation.id)
            } catch {
                Log.multichain.w(
                    "gasless fee priced again does not hold to the confirmed one",
                    error: error,
                    extraInfo: ["assetId": transfer.asset.asset.assetId, "feeAssetId": assetId]
                )
                return .failure(.multichainTransactionFailure(.relayerQuoteUnavailable(reason: error.logDescription)))
            }
        }

        if let refusal = Self.refusal(of: emulation, call: quote.call, chain: transfer.chain, paidWith: selected, now: now()) {
            Log.multichain.e(
                "gasless operation not signed: the relayer built another operation",
                extraInfo: ["assetId": transfer.asset.asset.assetId, "feeAssetId": assetId, "reason": refusal]
            )
            return .failure(.multichainTransactionFailure(.relayerQuoteUnavailable(reason: refusal)))
        }

        // The user can read the review past the relayer's deadline. A deadline the device's clock had
        // behind it already is left to the relayer to judge, as it always was.
        let wasLive = !emulation.isExpired(at: now())
        do throws(OperationRefusal) {
            try await gate.clear(Self.presentation(of: selected, on: transfer.chain), consent: consent) {
                try [Self.signable(of: emulation, paidWith: selected, transfer: transfer)]
            }
        } catch .declined {
            return .failure(.cancelledByUser)
        } catch {
            return .failure(.multichainTransactionFailure(.internal(reason: "the relayed transfer could not be reviewed: \(error)")))
        }
        guard !wasLive || !emulation.isExpired(at: now()) else {
            return .failure(.multichainTransactionFailure(.operationExpired))
        }
        // The estimate the method was chosen by can be stale too: the relayer must not be asked to
        // sponsor a transfer the wallet can no longer pay for.
        guard await !isInsufficient(selected.priced(emulation.fee), transfer: transfer, forPayment: true) else {
            return .failure(.multichainTransactionFailure(.insufficientSelectedFee))
        }
        // The PIN is already in: a screen closed while the operation was built again sends nothing.
        if rebuildsOnSend, Task.isCancelled {
            return .failure(.cancelledByUser)
        }

        let signedOperation: Data
        do {
            signedOperation = try await signer.signRelayedOperation(
                passcodeProvider: signingPasscodeProvider,
                wallet: transfer.wallet,
                chain: transfer.chain,
                operation: emulation.operation
            )
        } catch {
            if case .canceled = error {
                return .failure(.cancelledByUser)
            }
            Log.multichain.e("gasless operation signing failed", error: error)
            return .failure(.multichainTransactionFailure(error))
        }

        let txHash: String?
        do {
            txHash = try await relayer.send(wallet: transfer.wallet, signedOperation: signedOperation)
        } catch {
            Log.multichain.e(
                "gasless send failed",
                error: error,
                extraInfo: ["assetId": transfer.asset.asset.assetId, "feeAssetId": assetId]
            )
            switch error as? EVMGaslessRelayerError {
            case .quoteExpired:
                return .failure(.multichainTransactionFailure(.relayerQuoteExpired))
            case let .malformedEnvelope(reason):
                return .failure(.multichainTransactionFailure(.internal(reason: reason)))
            // A retry builds another transaction, so one the relayer may have broadcast is not retried.
            case .rejected(_, true) where rebuildsOnSend:
                return .failure(.multichainTransactionFailure(.relayerOutcomeUnknown(reason: error.logDescription)))
            case .rejected:
                return .failure(.multichainTransactionFailure(.relayerRejected(reason: error.logDescription)))
            case nil:
                return .failure(.multichainTransactionFailure(.relayerOutcomeUnknown(reason: error.logDescription)))
            }
        }
        Log.multichain.i(
            "gasless send handed to the relayer",
            extraInfo: ["assetId": transfer.asset.asset.assetId, "feeAssetId": assetId, "txHash": txHash ?? "none"]
        )
        return .success(txHash)
    }

    private static func refusal(
        of emulation: EVMGaslessEmulation,
        call: EVMGaslessCall,
        chain: MultichainChain,
        paidWith fee: EVMGaslessFeeOption,
        now: Date
    ) -> String? {
        // Solana's relayer builds the whole transaction: emulation refuses one the sender pays the fee of,
        // and the review holds it to the transfer's intent.
        guard chain.isEVM else {
            return nil
        }
        let relayedFee: HermesExecute.Fee
        if fee.isBattery {
            relayedFee = .battery
        } else if case let .asset(_, _, _, contract) = AssetIdComponents(assetId: emulation.assetId) {
            relayedFee = .token(contract: contract, amount: emulation.fee)
        } else {
            return "the fee asset \(emulation.assetId) is not a token"
        }
        return HermesExecute.refusal(
            of: emulation.operation,
            calls: [.init(call)],
            chain: chain,
            owner: call.sender,
            fee: relayedFee,
            now: emulation.deadlineReference(at: now)
        )
    }

    /// What `send` signs for `emulation`: the relayer's operation, held to the amount sent and to a
    /// fee in a token at the most it may rise to.
    private static func signable(
        of emulation: EVMGaslessEmulation,
        paidWith fee: EVMGaslessFeeOption,
        transfer: Transfer
    ) throws -> SignableOperation {
        let tokenFee: OperationIntent.Spend? = if case let .token(asset, confirmed) = fee.payer {
            .relayerFee(confirmed, in: asset)
        } else {
            nil
        }
        return try SignableOperation(
            operation: emulation.operation.operation,
            account: ChainKitOperationSender.account(wallet: transfer.wallet, chain: transfer.chain, holding: transfer.asset.asset),
            intent: .send(transfer.amount, of: transfer.asset.asset, to: transfer.recipient, fee: tokenFee),
            fidelity: .exact
        )
    }

    /// Charges are asked about, and on Solana a fee in a token too. Elsewhere a fee in a token is only
    /// logged until the relayer's operation states it, or the review would read the fee's transfer as
    /// paying someone else.
    static func presentation(of fee: EVMGaslessFeeOption, on chain: MultichainChain) -> OperationPresentation {
        fee.isBattery || chain == .sol ? .ask : .logOnly
    }

    static func isRelayAllowed(by wallet: Wallet) -> Bool {
        wallet.isBatteryEnable
    }

    /// A fee priced again holds to the one the user confirmed by the rules of relayed swaps: charges
    /// strictly, a token within the tolerance its moving rate gets.
    private static func requireConfirmedFee(
        _ fee: BigUInt,
        of selected: EVMGaslessFeeOption,
        operationId: String
    ) throws(MultichainSwapExecutionFailure) {
        switch selected.payer {
        case let .battery(confirmedCharges):
            // The balance is weighed right after, with the failure the screen has for a shortage.
            try MultichainSwapBatteryFeeRules.requireQuote(
                Int(clamping: fee),
                confirmedCharges: confirmedCharges,
                available: .unknown,
                payloadId: operationId
            )
        case let .token(_, confirmedFee):
            try MultichainSwapBatteryFeeRules.requireTokenQuote(fee, confirmedAmount: confirmedFee, payloadId: operationId)
        case .native:
            throw .internal(reason: "the chain's coin is not relayed")
        }
    }

    /// The method an estimation names, not yet weighed against the wallet's balances.
    private func option(
        for estimation: EVMGaslessEstimation,
        transfer: Transfer,
        migrationPending: Bool
    ) -> EVMGaslessFeeOption? {
        if estimation.isBattery {
            let charges = Int(clamping: estimation.fee)
            guard charges > 0 else {
                return nil
            }
            return EVMGaslessFeeOption(
                payer: .battery(charges: charges),
                relayerAssetId: estimation.asset.id,
                isAvailable: estimation.isAvailable || migrationPending
            )
        }
        let sent = transfer.asset.asset
        let asset = AssetIdComponents.isSameAsset(estimation.asset.id, sent.assetId)
            ? sent
            : MultichainAssetDetails(
                assetId: estimation.asset.id,
                name: estimation.asset.name,
                symbol: estimation.asset.symbol,
                decimals: estimation.asset.decimals,
                image: estimation.asset.image ?? ""
            )
        return EVMGaslessFeeOption(
            payer: .token(asset, fee: estimation.fee),
            relayerAssetId: estimation.asset.id,
            isAvailable: estimation.isAvailable
        )
    }

    /// The wallet's entries for the tokens `options` would pay in, read together. The sent token
    /// comes with the transfer, and a token the relayer has ruled out cannot pay whatever the balance.
    private func loadWalletTokens(
        weighing options: [EVMGaslessFeeOption],
        transfer: Transfer
    ) async -> [String: MultichainAsset] {
        let assetIds = options.compactMap { option -> String? in
            guard option.isAvailable,
                  case let .token(asset, _) = option.payer,
                  !AssetIdComponents.isSameAsset(asset.assetId, transfer.asset.asset.assetId)
            else {
                return nil
            }
            return asset.assetId
        }
        guard !assetIds.isEmpty else {
            return [:]
        }
        return await walletTokens(assetIds, transfer.wallet)
    }

    private func isInsufficient(_ option: EVMGaslessFeeOption, transfer: Transfer, forPayment: Bool = false) async -> Bool {
        let heldTokens = await loadWalletTokens(weighing: [option], transfer: transfer)
        return await isInsufficient(option, transfer: transfer, heldTokens: heldTokens, forPayment: forPayment)
    }

    /// Whether the wallet covers the fee. A fee in the asset being sent has to fit next to the
    /// amount, not just under the balance; a balance that cannot be read cannot cover anything.
    private func isInsufficient(
        _ option: EVMGaslessFeeOption,
        transfer: Transfer,
        heldTokens: [String: MultichainAsset],
        forPayment: Bool = false
    ) async -> Bool {
        switch option.payer {
        case let .battery(charges):
            switch await(forPayment ? currentBatteryCharges(transfer.wallet) : batteryCharges(transfer.wallet)) {
            case .unavailable:
                return true
            case .unknown:
                return false
            case let .available(availableCharges):
                return availableCharges < charges
            }
        case let .token(asset, fee):
            if AssetIdComponents.isSameAsset(asset.assetId, transfer.asset.asset.assetId) {
                return fee + transfer.amount > transfer.asset.balance
            }
            guard option.isAvailable else {
                return option.isInsufficient
            }
            guard let balance = heldTokens[asset.assetId]?.balance else {
                return true
            }
            return fee > balance
        case .native:
            return option.isInsufficient
        }
    }
}
