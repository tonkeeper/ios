import BigInt
import Foundation
import TKLogging
import TonSwift

struct MultichainSwapTonBatteryFeeEngine: MultichainSwapRelayedFeeEngine {
    private let transferService: TransferService
    private let balanceService: BalanceService
    private let batteryChargesReader: BatteryChargesReader
    private let batteryCalculation: BatteryCalculation
    private let configuration: Configuration
    private let chainKitService: ChainKitService
    private let mnemonicAccess: MnemonicAccess

    init(
        transferService: TransferService,
        balanceService: BalanceService,
        batteryService: BatteryService,
        batteryCalculation: BatteryCalculation,
        configuration: Configuration,
        chainKitService: ChainKitService,
        mnemonicAccess: MnemonicAccess
    ) {
        self.transferService = transferService
        self.balanceService = balanceService
        batteryChargesReader = BatteryChargesReader(
            batteryService: batteryService,
            batteryCalculation: batteryCalculation
        )
        self.batteryCalculation = batteryCalculation
        self.configuration = configuration
        self.chainKitService = chainKitService
        self.mnemonicAccess = mnemonicAccess
    }

    let chain = MultichainChain.ton

    func options(context: MultichainSwapFeeContext) async -> [MultichainSwapFeeOption] {
        guard let prepared = await preparedTransfer(context: context) else {
            return []
        }
        let emulation = prepared.emulation
        let requiredCharges = batteryCalculation.calculateCharges(tonAmount: emulation.amount)
        let availableCharges = await batteryChargesReader.availableCharges(wallet: context.wallet)
        Log.multichainSwap.i(
            "battery ton swap priced",
            extraInfo: [
                "payloadId": context.payloadId,
                "requiredCharges": requiredCharges.map { "\($0)" } ?? "unpriced",
                "availableCharges": availableCharges.logValue,
            ]
        )
        return [
            MultichainSwapBatteryFeeRules.option(
                charges: requiredCharges,
                excessCharges: emulation.excess.flatMap {
                    batteryCalculation.calculateCharges(tonAmount: $0)
                },
                availableCharges: availableCharges
            ),
        ]
    }

    func send(
        context: MultichainSwapFeeContext,
        confirmed: MultichainSwapRelayedFee,
        passcodeProvider: @escaping () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> String {
        let payloadId = context.payloadId
        guard case let .batteryCharges(confirmedCharges) = confirmed else {
            throw .internal(reason: "a ton swap can only be relayed against battery charges")
        }
        guard let prepared = await preparedTransfer(context: context) else {
            throw .internal(reason: "battery cannot pay for swap payload \(payloadId)")
        }
        let availableCharges = await batteryChargesReader.availableCharges(wallet: context.wallet)
        try MultichainSwapBatteryFeeRules.requireCharges(
            confirmedCharges,
            available: availableCharges,
            payloadId: payloadId
        )
        guard let liveCharges = batteryCalculation.calculateCharges(tonAmount: prepared.emulation.amount) else {
            throw .preparationFailed(
                kind: .networkError,
                reason: "failed to re-price swap payload \(payloadId) against battery"
            )
        }
        try MultichainSwapBatteryFeeRules.requireQuote(
            liveCharges,
            confirmedCharges: confirmedCharges,
            available: availableCharges,
            payloadId: payloadId
        )
        let signedTransactions = try await relay(
            prepared.transfer,
            wallet: context.wallet,
            payloadId: payloadId,
            passcodeProvider: passcodeProvider
        ).get()
        guard let boc = signedTransactions.bocs.first else {
            throw .broadcastFailed(
                payloadId: payloadId,
                kind: .unknown,
                reason: "battery relay returned no signed message"
            )
        }
        do {
            return try TonMessageHash.hex(signedBocBase64: boc)
        } catch {
            Log.multichainSwap.w(
                "battery swap hash resolution failed",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            // The relayer already holds the message, so this reads as an unknown outcome rather than
            // an internal error: signing again could land a second swap.
            throw .broadcastFailed(
                payloadId: payloadId,
                kind: .unknown,
                reason: "failed to derive the hash of a relayed swap: \(error.logDescription)"
            )
        }
    }
}

private extension MultichainSwapTonBatteryFeeEngine {
    struct PreparedTransfer {
        let transfer: Transfer
        let emulation: BatteryEmulation
    }

    struct BatteryEmulation {
        let amount: BigUInt
        let excess: BigUInt?
        let sourceAmount: TransferEmulationResult.Extra.Amount
    }

    func preparedTransfer(context: MultichainSwapFeeContext) async -> PreparedTransfer? {
        let isBatteryEnabled = await configuration.isBatteryEnable(network: context.wallet.network)
        let isBatterySendEnabled = await configuration.isBatterySendEnable(network: context.wallet.network)
        guard MultichainSwapBatteryFeeRules.isBatteryAllowed(
            wallet: context.wallet,
            isBatteryEnabled: isBatteryEnabled,
            isBatterySendEnabled: isBatterySendEnabled
        ), case .tonJetton = MultichainSwapBatteryFeeRules.relayedAsset(
            wallet: context.wallet,
            sourceAsset: context.sourceAsset,
            requiresApproval: context.requiresApproval,
            isTRXOnlyRegion: configuration.isTRXOnlyRegion(network: context.wallet.network)
        ) else {
            Log.multichainSwap.i(
                "battery ton swap not offered",
                extraInfo: [
                    "payloadId": context.payloadId,
                    "sourceAsset": context.sourceAsset.asset.assetId,
                    "batteryEnabled": "\(isBatteryEnabled)",
                    "batterySendEnabled": "\(isBatterySendEnabled)",
                    "requiresApproval": "\(context.requiresApproval)",
                ]
            )
            return nil
        }

        switch context.payload {
        case let .ton(message):
            guard let transfer = makeTransfer(
                wallet: context.wallet,
                message: message,
                payloadId: context.payloadId
            ) else {
                return nil
            }
            guard TransferService.isRelayerEnabled(wallet: context.wallet, transfer: transfer) else {
                Log.multichainSwap.i(
                    "battery ton swap not offered: relayer disabled for this wallet",
                    extraInfo: ["payloadId": context.payloadId]
                )
                return nil
            }
            guard isPayloadPreserved(
                wallet: context.wallet,
                message: message,
                payloadId: context.payloadId
            ), let emulation = await emulate(wallet: context.wallet, transfer: transfer)
            else {
                return nil
            }
            return PreparedTransfer(transfer: transfer, emulation: emulation)
        case let .tonJettonDeposit(deposit):
            return await preparedJettonDeposit(
                context: context,
                deposit: deposit
            )
        case .tron:
            return nil
        }
    }

    func preparedJettonDeposit(
        context: MultichainSwapFeeContext,
        deposit: TonJettonSwapDeposit
    ) async -> PreparedTransfer? {
        let jettons: [JettonBalance]
        do {
            jettons = try balanceService.getBalance(wallet: context.wallet).balance.jettonsBalance
        } catch {
            Log.multichainSwap.w(
                "battery jetton swap option skipped: wallet balance is unavailable",
                error: error,
                extraInfo: ["payloadId": context.payloadId]
            )
            return nil
        }
        guard let jettonItem = TonJettonSwapTransferFactory.jettonItem(
            sourceAsset: context.sourceAsset,
            jettons: jettons
        ) else {
            Log.multichainSwap.i(
                "battery jetton swap not offered: source jetton wallet is unavailable",
                extraInfo: [
                    "payloadId": context.payloadId,
                    "sourceAsset": context.sourceAsset.asset.assetId,
                ]
            )
            return nil
        }
        let minimumTransferAmount = await transferService.transferCost(
            wallet: context.wallet,
            jettonMasterAddress: jettonItem.jettonInfo.address
        )
        guard let initialTransfer = TonJettonSwapTransferFactory.makeTransfer(
            sourceAsset: context.sourceAsset,
            deposit: deposit,
            jettons: jettons,
            transferAmount: minimumTransferAmount
        ), let initialEmulation = await emulate(wallet: context.wallet, transfer: initialTransfer)
        else {
            return nil
        }
        let fundedTransferAmount = TonJettonSwapTransferFactory.requiredTransferAmount(
            minimum: minimumTransferAmount,
            emulationAmount: initialEmulation.sourceAmount
        )
        guard fundedTransferAmount != minimumTransferAmount else {
            return PreparedTransfer(transfer: initialTransfer, emulation: initialEmulation)
        }
        guard let fundedTransfer = TonJettonSwapTransferFactory.makeTransfer(
            sourceAsset: context.sourceAsset,
            deposit: deposit,
            jettons: jettons,
            transferAmount: fundedTransferAmount
        ), let fundedEmulation = await emulate(wallet: context.wallet, transfer: fundedTransfer)
        else {
            return nil
        }
        let validatedTransferAmount = TonJettonSwapTransferFactory.requiredTransferAmount(
            minimum: minimumTransferAmount,
            emulationAmount: fundedEmulation.sourceAmount
        )
        guard validatedTransferAmount <= fundedTransferAmount else {
            Log.multichainSwap.w(
                "battery jetton swap option skipped: attached amount did not stabilize",
                extraInfo: [
                    "payloadId": context.payloadId,
                    "attachedAmount": fundedTransferAmount.description,
                    "requiredAmount": validatedTransferAmount.description,
                ]
            )
            return nil
        }
        return PreparedTransfer(transfer: fundedTransfer, emulation: fundedEmulation)
    }

    /// A relayed send re-serializes the message body of a custom-payload jetton, which keeps only a
    /// ref-based forward payload — and the aggregator's swap instruction may be inlined in it. The
    /// swap would then land at the router as a plain transfer, so battery is not offered at all,
    /// and a balance we cannot read is treated as the risky case.
    /// Reads the cached balance rather than reloading it: this runs on every quote refresh, and
    /// `loadWalletBalance` fans out across every chain and rewrites the stored snapshot.
    func isPayloadPreserved(
        wallet: Wallet,
        message: TonSwapMessage,
        payloadId: String
    ) -> Bool {
        guard message.payload != nil else {
            return true
        }
        let recipient: Address
        do {
            recipient = try AnyAddress(rawAddress: message.to).address
        } catch {
            return false
        }
        do {
            let balance = try balanceService.getBalance(wallet: wallet)
            let recipientJetton = balance.balance.jettonsBalance.first {
                $0.item.walletAddress == recipient
            }
            return recipientJetton?.item.jettonInfo.hasCustomPayload != true
        } catch {
            Log.multichainSwap.w(
                "battery swap option skipped: jetton balance is unavailable",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            return false
        }
    }

    func makeTransfer(
        wallet: Wallet,
        message: TonSwapMessage,
        payloadId: String
    ) -> Transfer? {
        guard let amount = UInt64(message.amount.description) else {
            Log.multichainSwap.w(
                "battery swap option skipped: message amount exceeds a ton transfer",
                extraInfo: [
                    "payloadId": payloadId,
                    "amount": message.amount.description,
                ]
            )
            return nil
        }
        let sender: Address
        let recipient: AnyAddress
        do {
            sender = try wallet.address
            recipient = try AnyAddress(rawAddress: message.to)
        } catch {
            Log.multichainSwap.w(
                "battery swap option skipped: unusable ton message addresses",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            return nil
        }
        return .multichainSwap(
            SignRawRequest(
                messages: [
                    SignRawRequestMessage(
                        address: recipient,
                        amount: amount,
                        stateInit: message.stateInit,
                        payload: message.payload
                    ),
                ],
                validUntil: nil,
                from: sender,
                messagesVariants: nil
            )
        )
    }

    func emulate(wallet: Wallet, transfer: Transfer) async -> BatteryEmulation? {
        let result: TransferEmulationResult
        do {
            result = try await transferService.emulate(
                wallet: wallet,
                transfer: transfer,
                preferredExtraType: .battery,
                includeUnavailableBattery: true
            )
        } catch {
            Log.multichainSwap.w("battery swap fee emulation failed", error: error)
            return nil
        }
        // Emulation silently falls back to the wallet's own TON when battery cannot price the
        // message; only an actual battery estimate may price this option.
        guard result.transferType.isBattery else {
            return nil
        }
        let amount: BigUInt = switch result.extra.amount {
        case let .fee(value): value
        case let .refund(value): value
        }
        return BatteryEmulation(
            amount: amount,
            excess: result.extra.excess.map { BigUInt($0) },
            sourceAmount: result.extra.amount
        )
    }

    /// The excess address handed over here is only a fallback: the send path replaces it with the
    /// battery's own, which is what the emulation above was priced against.
    func relay(
        _ transfer: Transfer,
        wallet: Wallet,
        payloadId: String,
        passcodeProvider: @escaping () async -> String?
    ) async -> Result<SignedTransactions, MultichainSwapExecutionFailure> {
        let excessAddress: Address
        do {
            excessAddress = try wallet.address
        } catch {
            return .failure(
                .preparationFailed(
                    kind: .internalError,
                    reason: "failed to resolve the wallet address of a relayed swap"
                )
            )
        }
        do {
            let signedTransactions = try await transferService.sendTransaction(
                wallet: wallet,
                transfer: transfer,
                transferType: .battery(excessAddress: excessAddress),
                signClosure: { transferData in
                    await sign(
                        transferData: transferData,
                        wallet: wallet,
                        payloadId: payloadId,
                        passcodeProvider: passcodeProvider
                    )
                }
            )
            return .success(signedTransactions)
        } catch {
            switch error {
            case let .firstOption(transferError):
                return .failure(failure(transferError, payloadId: payloadId))
            case let .secondOption(signFailure):
                return .failure(signFailure)
            }
        }
    }

    /// Only `sendFailed` leaves the outcome unknown — the relayer may already hold the message — so
    /// it is the one failure that must not read as "nothing happened" to a caller deciding whether
    /// to offer a retry.
    func failure(
        _ error: TransferError,
        payloadId: String
    ) -> MultichainSwapExecutionFailure {
        Log.multichainSwap.w(
            "battery swap relay failed",
            error: error,
            extraInfo: ["payloadId": payloadId]
        )
        switch error {
        case let .sendFailed(message):
            return .broadcastFailed(
                payloadId: payloadId,
                kind: .unknown,
                reason: "battery relay rejected the swap: \(message ?? "no message")"
            )
        case .nothingToSend,
             .unsupportedTransfer,
             .failedToCreateTransferData,
             .noExcessesAddress,
             .noJettonWalletAddress:
            return .preparationFailed(
                kind: .internalError,
                reason: "battery relay could not build the swap: \(error.localizedDescription)"
            )
        }
    }

    func sign(
        transferData: TransferData,
        wallet: Wallet,
        payloadId: String,
        passcodeProvider: () async -> String?
    ) async -> Result<SignedTransactions, MultichainSwapExecutionFailure> {
        guard let passcode = await passcodeProvider() else {
            return .failure(.canceled)
        }
        do {
            let mnemonic = try await mnemonicAccess.getMnemonic(wallet: wallet, passcode: passcode)
            let keyPair = try mnemonic.toKeyPair()
            let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
                .createUnsignedWalletTransfer(wallet: wallet)
            let signed = try TransferSigner.signWalletTransfer(
                walletTransfer,
                wallet: wallet,
                seqno: transferData.seqno,
                signer: WalletTransferSecretKeySigner(secretKey: keyPair.privateKey.data)
            )
            let boc = try signed.toBoc().base64EncodedString()
            // A hash that cannot be derived has to fail here, while nothing has been handed over:
            // after the relay it would leave a sent swap the screen is free to send again.
            _ = try TonMessageHash.hex(signedBocBase64: boc)
            return .success(
                SignedTransactions(
                    boc: boc,
                    batterySendProof: chainKitService.batterySendProof(
                        wallet: wallet,
                        mnemonic: mnemonic.mnemonicWords.joined(separator: " "),
                        boc: boc
                    )
                )
            )
        } catch {
            Log.multichainSwap.w(
                "battery swap signing failed",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            return .failure(
                .signingFailed(
                    payloadId: payloadId,
                    kind: .signInternalError,
                    reason: "failed to sign a relayed swap: \(error.localizedDescription)"
                )
            )
        }
    }
}
