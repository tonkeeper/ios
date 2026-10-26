import BigInt
import Foundation
import TKLogging

/// Prices and sends an EVM transfer through the battery's relayer, which pays the chain and takes
/// its fee in battery charges or in a token of the chain. The chain's own coin stays with ChainKit:
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

        func selected(picked: TransactionConfirmationModel.ExtraType?) -> EVMGaslessFeeOption? {
            EVMGaslessFeeSelection.resolve(options, picked: picked)
        }
    }

    private let relayer: EVMGaslessRelaying
    private let signer: MultichainRelayedOperationSigner
    /// The remote battery switches; the wallet's own are read here.
    private let isEnabled: (Wallet) async -> Bool
    private let batteryCharges: (Wallet) async -> BatteryChargesAvailability
    /// The wallet's own entries for assets other than the one being sent, by the ids they are asked
    /// for; an asset the wallet does not list, or whose listing cannot be read, is missing from the answer.
    private let walletTokens: (_ assetIds: [String], _ wallet: Wallet) async -> [String: MultichainAsset]
    private let now: () -> Date

    init(
        relayer: EVMGaslessRelaying,
        signer: MultichainRelayedOperationSigner,
        isEnabled: @escaping (Wallet) async -> Bool,
        batteryCharges: @escaping (Wallet) async -> BatteryChargesAvailability,
        walletTokens: @escaping (_ assetIds: [String], _ wallet: Wallet) async -> [String: MultichainAsset],
        now: @escaping () -> Date = Date.init
    ) {
        self.relayer = relayer
        self.signer = signer
        self.isEnabled = isEnabled
        self.batteryCharges = batteryCharges
        self.walletTokens = walletTokens
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
        let options = await reweighed(
            estimations.compactMap { option(for: $0, transfer: transfer) },
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
            if let emulation = current.emulation, emulation.assetId == assetId, !emulation.isExpired(at: now()) {
                break
            }
            current.emulation = nil
            do {
                let emulation = try await relayer.emulate(wallet: transfer.wallet, call: current.call, assetId: assetId)
                var priced = selected.priced(emulation.fee)
                priced.isInsufficient = await isInsufficient(priced, transfer: transfer)
                guard priced.canPay else {
                    current.options = EVMGaslessFeeSelection.rulingOut(priced, in: current.options)
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

    /// Sends the transfer through the relayer, paying with `selected`.
    func send(
        _ quote: Quote,
        selected: EVMGaslessFeeOption,
        transfer: Transfer,
        passcodeProvider: @escaping () async -> String?
    ) async -> Result<Void, TransactionConfirmationError> {
        guard let assetId = selected.relayerAssetId else {
            return .failure(.multichainTransactionFailure(.internal(reason: "the chain's coin is not relayed")))
        }
        // The quote can be minutes old by the time the user confirms: price the chosen method again
        // rather than ask the relayer to broadcast an operation it has already forgotten.
        let emulation: EVMGaslessEmulation
        if let quoted = quote.emulation, quoted.assetId == assetId, !quoted.isExpired(at: now()) {
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
        }
        // The estimate the method was chosen by can be stale too: the relayer must not be asked to
        // sponsor a transfer the wallet can no longer pay for.
        guard await !isInsufficient(selected.priced(emulation.fee), transfer: transfer) else {
            return .failure(.multichainTransactionFailure(.insufficientSelectedFee))
        }

        let signedOperation: Data
        do {
            signedOperation = try await signer.signRelayedOperation(
                passcodeProvider: passcodeProvider,
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

        do {
            try await relayer.send(wallet: transfer.wallet, signedOperation: signedOperation)
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
            case .rejected:
                return .failure(.multichainTransactionFailure(.relayerRejected(reason: error.logDescription)))
            case nil:
                return .failure(.multichainTransactionFailure(.relayerOutcomeUnknown(reason: error.logDescription)))
            }
        }
        return .success(())
    }

    /// The wallet's own battery switches, the same ones a TON jetton transfer is relayed under:
    /// the wallet has no switch of its own for a coin transfer, so the token one covers both.
    static func isRelayAllowed(by wallet: Wallet) -> Bool {
        wallet.isBatteryEnable && wallet.batterySettings.isJettonTransactionEnable
    }

    /// The method an estimation names, not yet weighed against the wallet's balances.
    private func option(
        for estimation: EVMGaslessEstimation,
        transfer: Transfer
    ) -> EVMGaslessFeeOption? {
        if estimation.isBattery {
            let charges = Int(clamping: estimation.fee)
            guard charges > 0 else {
                return nil
            }
            return EVMGaslessFeeOption(
                payer: .battery(charges: charges),
                relayerAssetId: estimation.asset.id,
                isAvailable: estimation.isAvailable
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

    private func isInsufficient(_ option: EVMGaslessFeeOption, transfer: Transfer) async -> Bool {
        let heldTokens = await loadWalletTokens(weighing: [option], transfer: transfer)
        return await isInsufficient(option, transfer: transfer, heldTokens: heldTokens)
    }

    /// Whether the wallet covers the fee. A fee in the asset being sent has to fit next to the
    /// amount, not just under the balance; a balance that cannot be read cannot cover anything.
    private func isInsufficient(
        _ option: EVMGaslessFeeOption,
        transfer: Transfer,
        heldTokens: [String: MultichainAsset]
    ) async -> Bool {
        switch option.payer {
        case let .battery(charges):
            switch await batteryCharges(transfer.wallet) {
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
