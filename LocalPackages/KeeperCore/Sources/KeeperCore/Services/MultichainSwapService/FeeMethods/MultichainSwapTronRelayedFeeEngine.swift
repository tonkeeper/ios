import BigInt
import Foundation
import KeeperCoreSensitive
import TKLogging
import TonSwift
import TronSwift

/// Relays a TRON swap. A TRON route is a transfer of the source asset to the aggregator's deposit
/// address, so the relayer signs and broadcasts the same transaction the wallet would have sent
/// itself; what it bills for that is either the battery's charges or, as an instant fee, the wallet's
/// GRAM — both quoted by the same TRON estimate.
struct MultichainSwapTronRelayedFeeEngine: MultichainSwapRelayedFeeEngine {
    private let tronUsdtApi: TronUSDTAPI
    private let transactionSender: TronUSDTTransactionSender
    private let tonFeePaymentBuilder: TronUSDTTonFeePaymentBuilder
    private let batteryChargesReader: BatteryChargesReader
    private let balanceService: BalanceService
    private let configuration: Configuration
    private let chainKitService: ChainKitService
    private let mnemonicAccess: MnemonicAccess

    init(
        tronUsdtApi: TronUSDTAPI,
        sendService: SendService,
        balanceService: BalanceService,
        batteryService: BatteryService,
        batteryCalculation: BatteryCalculation,
        configuration: Configuration,
        chainKitService: ChainKitService,
        mnemonicAccess: MnemonicAccess
    ) {
        self.tronUsdtApi = tronUsdtApi
        transactionSender = TronUSDTTransactionSender(
            tronUsdtApi: tronUsdtApi,
            feeOptionsResolver: TronUSDTFeeOptionsResolver(configuration: configuration)
        )
        tonFeePaymentBuilder = TronUSDTTonFeePaymentBuilder(
            sendService: sendService,
            balanceService: balanceService
        )
        batteryChargesReader = BatteryChargesReader(
            batteryService: batteryService,
            batteryCalculation: batteryCalculation
        )
        self.balanceService = balanceService
        self.configuration = configuration
        self.chainKitService = chainKitService
        self.mnemonicAccess = mnemonicAccess
    }

    let chain = MultichainChain.tron

    func options(context: MultichainSwapFeeContext) async -> [MultichainSwapFeeOption] {
        guard let transfer = await relayedTransfer(context: context),
              let estimate = await estimate(transfer, wallet: context.wallet)
        else {
            return []
        }
        var options = [MultichainSwapFeeOption]()
        if await isBatteryAllowed(wallet: context.wallet) {
            let availableCharges = await batteryChargesReader.availableCharges(wallet: context.wallet)
            Log.multichainSwap.i(
                "battery tron swap priced",
                extraInfo: [
                    "payloadId": context.payloadId,
                    "requiredCharges": "\(estimate.requiredBatteryCharges)",
                    "availableCharges": availableCharges.logValue,
                    "energy": "\(estimate.energy)",
                    "bandwidth": "\(estimate.bandwidth)",
                ]
            )
            options.append(
                MultichainSwapBatteryFeeRules.option(
                    charges: estimate.requiredBatteryCharges,
                    excessCharges: nil,
                    availableCharges: availableCharges
                )
            )
        }
        if let gramOption = gramOption(estimate: estimate, wallet: context.wallet, payloadId: context.payloadId) {
            options.append(gramOption)
        }
        return options
    }

    func send(
        context: MultichainSwapFeeContext,
        confirmed: MultichainSwapRelayedFee,
        passcodeProvider: @escaping () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> String {
        let payloadId = context.payloadId
        guard let transfer = await relayedTransfer(context: context) else {
            throw .internal(reason: "no relayed method can pay for swap payload \(payloadId)")
        }
        switch confirmed {
        case let .batteryCharges(confirmedCharges):
            return try await sendWithBattery(
                transfer,
                wallet: context.wallet,
                confirmedCharges: confirmedCharges,
                payloadId: payloadId,
                passcodeProvider: passcodeProvider
            )
        case let .gram(confirmedAmountNano):
            return try await sendWithGram(
                transfer,
                wallet: context.wallet,
                confirmedAmountNano: confirmedAmountNano,
                payloadId: payloadId,
                passcodeProvider: passcodeProvider
            )
        }
    }
}

private extension MultichainSwapTronRelayedFeeEngine {
    struct RelayedTransfer {
        let sender: TronSwift.Address
        let recipient: TronSwift.Address
        let amount: BigUInt
        let asset: MultichainSwapRelayedAsset.TronAsset
    }

    func sendWithBattery(
        _ transfer: RelayedTransfer,
        wallet: Wallet,
        confirmedCharges: Int,
        payloadId: String,
        passcodeProvider: @escaping () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> String {
        guard await isBatteryAllowed(wallet: wallet) else {
            throw .internal(reason: "battery cannot pay for swap payload \(payloadId)")
        }
        let availableCharges = await batteryChargesReader.availableCharges(wallet: wallet)
        try MultichainSwapBatteryFeeRules.requireCharges(
            confirmedCharges,
            available: availableCharges,
            payloadId: payloadId
        )
        // The relayer is billed for the resources it burns, so they are re-quoted against the chain
        // as it is now rather than as the confirmation screen saw it.
        guard let estimate = await estimate(transfer, wallet: wallet) else {
            throw .preparationFailed(
                kind: .networkError,
                reason: "failed to re-quote the tron resources of swap payload \(payloadId)"
            )
        }
        try MultichainSwapBatteryFeeRules.requireQuote(
            estimate.requiredBatteryCharges,
            confirmedCharges: confirmedCharges,
            available: availableCharges,
            payloadId: payloadId
        )
        let mnemonic = try await mnemonic(
            wallet: wallet,
            payloadId: payloadId,
            passcodeProvider: passcodeProvider
        )
        let signedTransaction = try await signedTransaction(
            transfer,
            wallet: wallet,
            mnemonic: mnemonic,
            payloadId: payloadId
        )
        try await relay(
            signedTransaction,
            transfer: transfer,
            wallet: wallet,
            selectedExtraType: .battery,
            estimate: estimate,
            instantFeePayment: nil,
            payloadId: payloadId
        )
        return signedTransaction.txID
    }

    func sendWithGram(
        _ transfer: RelayedTransfer,
        wallet: Wallet,
        confirmedAmountNano: BigUInt,
        payloadId: String,
        passcodeProvider: @escaping () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> String {
        guard let estimate = await estimate(transfer, wallet: wallet),
              let quote = gramQuote(estimate: estimate)
        else {
            throw .preparationFailed(
                kind: .networkError,
                reason: "failed to re-quote the gram instant fee of swap payload \(payloadId)"
            )
        }
        // The relayer bills what it asks for now, not what the confirmation screen showed.
        try MultichainSwapBatteryFeeRules.requireGramQuote(
            quote.amountNano,
            confirmedAmountNano: confirmedAmountNano,
            payloadId: payloadId
        )
        if quote.amountNano > confirmedAmountNano {
            Log.multichainSwap.i(
                "gram instant fee drifted above the confirmed price, within tolerance",
                extraInfo: [
                    "payloadId": payloadId,
                    "quotedNano": quote.amountNano.description,
                    "confirmedNano": confirmedAmountNano.description,
                ]
            )
        }
        let mnemonic = try await mnemonic(
            wallet: wallet,
            payloadId: payloadId,
            passcodeProvider: passcodeProvider
        )
        let signedTransaction = try await signedTransaction(
            transfer,
            wallet: wallet,
            mnemonic: mnemonic,
            payloadId: payloadId
        )
        let instantFeePayment = try await instantFeePayment(
            quote,
            wallet: wallet,
            mnemonic: mnemonic,
            payloadId: payloadId
        )
        try await relay(
            signedTransaction,
            transfer: transfer,
            wallet: wallet,
            selectedExtraType: .default,
            estimate: estimate,
            instantFeePayment: instantFeePayment,
            payloadId: payloadId
        )
        return signedTransaction.txID
    }

    struct GramQuote {
        let amountNano: BigUInt
        let feeAddress: String
    }

    /// The instant fee as the TRON send screen reads it: a sender who has to pay the chain in TRX —
    /// activating the destination account does — leaves nothing for a sponsor to settle, and an
    /// amount of zero is no price at all rather than a free swap.
    func gramQuote(estimate: TronTransferFeeEstimate) -> GramQuote? {
        guard !estimate.requiresSelfPaidTRX,
              let amountNano = estimate.requiredTONAmountNano,
              amountNano > 0,
              let feeAddress = estimate.tonFeeAddress,
              !feeAddress.isEmpty
        else {
            return nil
        }
        return GramQuote(amountNano: amountNano, feeAddress: feeAddress)
    }

    func gramOption(
        estimate: TronTransferFeeEstimate,
        wallet: Wallet,
        payloadId: String
    ) -> MultichainSwapFeeOption? {
        guard let quote = gramQuote(estimate: estimate) else {
            Log.multichainSwap.i(
                "gram tron swap not offered: the relayer quoted no instant fee",
                extraInfo: [
                    "payloadId": payloadId,
                    "requiresSelfPaidTRX": "\(estimate.requiresSelfPaidTRX)",
                ]
            )
            return nil
        }
        // The fee travels as a TON transfer of its own, so the wallet has to cover its gas too.
        let requiredBalance = TronUSDTTonFeePaymentBuilder.requiredTonBalance(for: quote.amountNano)
        let balance = tonBalance(wallet: wallet, payloadId: payloadId)
        Log.multichainSwap.i(
            "gram tron swap priced",
            extraInfo: [
                "payloadId": payloadId,
                "requiredNano": requiredBalance.description,
                "balanceNano": balance?.description ?? "unknown",
            ]
        )
        return MultichainSwapFeeOption(
            cost: .gram(
                amountNano: quote.amountNano,
                // A balance that could not be read is the unknown the send path also refuses to call
                // insufficient: the payment builder still checks it against a fresh balance.
                isInsufficient: balance.map { $0 < requiredBalance } ?? false
            )
        )
    }

    /// Reads the cached balance rather than reloading it: this runs on every quote refresh, and
    /// `loadWalletBalance` fans out across every chain and rewrites the stored snapshot.
    func tonBalance(wallet: Wallet, payloadId: String) -> BigUInt? {
        do {
            let amount = try balanceService.getBalance(wallet: wallet).balance.tonBalance.amount
            return BigUInt(max(amount, 0))
        } catch {
            Log.multichainSwap.w(
                "gram tron swap balance unavailable",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            return nil
        }
    }

    func isBatteryAllowed(wallet: Wallet) async -> Bool {
        let isBatteryEnabled = await configuration.isBatteryEnable(network: wallet.network)
        let isBatterySendEnabled = await configuration.isBatterySendEnable(network: wallet.network)
        return MultichainSwapBatteryFeeRules.isBatteryAllowed(
            wallet: wallet,
            isBatteryEnabled: isBatteryEnabled,
            isBatterySendEnabled: isBatterySendEnabled
        )
    }

    func relayedTransfer(context: MultichainSwapFeeContext) async -> RelayedTransfer? {
        guard case let .tron(transfer) = context.payload else {
            return nil
        }
        let isTRXOnlyRegion = configuration.isTRXOnlyRegion(network: context.wallet.network)
        guard case let .tron(asset) = MultichainSwapBatteryFeeRules.relayedAsset(
            wallet: context.wallet,
            sourceAsset: context.sourceAsset,
            requiresApproval: context.requiresApproval,
            isTRXOnlyRegion: isTRXOnlyRegion
        ),
            case let .multichain(state) = context.wallet.multichain,
            let senderAddress = state.address(for: .tron)
        else {
            Log.multichainSwap.i(
                "relayed tron swap not offered",
                extraInfo: [
                    "payloadId": context.payloadId,
                    "sourceAsset": context.sourceAsset.asset.assetId,
                    "trxOnlyRegion": "\(isTRXOnlyRegion)",
                    "requiresApproval": "\(context.requiresApproval)",
                ]
            )
            return nil
        }
        do {
            return try RelayedTransfer(
                sender: TronSwift.Address(address: senderAddress),
                recipient: TronSwift.Address(address: transfer.to),
                amount: transfer.amount,
                asset: asset
            )
        } catch {
            Log.multichainSwap.w(
                "relayed tron swap skipped: unusable addresses",
                error: error,
                extraInfo: ["payloadId": context.payloadId]
            )
            return nil
        }
    }

    func estimate(
        _ transfer: RelayedTransfer,
        wallet: Wallet
    ) async -> TronTransferFeeEstimate? {
        do {
            switch transfer.asset {
            case .usdt:
                return try await tronUsdtApi.estimateTransferFees(
                    wallet: wallet,
                    address: transfer.sender,
                    method: TransferMethod(to: transfer.recipient, amount: transfer.amount)
                )
            case .trx:
                return try await tronUsdtApi.estimateNativeTransferFees(
                    wallet: wallet,
                    from: transfer.sender,
                    to: transfer.recipient,
                    amountSun: transfer.amount
                )
            }
        } catch {
            Log.multichainSwap.w("relayed tron swap fee estimation failed", error: error)
            return nil
        }
    }

    func relay(
        _ signedTransaction: Transaction,
        transfer: RelayedTransfer,
        wallet: Wallet,
        selectedExtraType: TransactionConfirmationModel.ExtraType,
        estimate: TronTransferFeeEstimate,
        instantFeePayment: TronUSDTTransactionSender.InstantFeePayment?,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) {
        do {
            try await transactionSender.send(
                signedTransaction: signedTransaction,
                selectedExtraType: selectedExtraType,
                wallet: wallet,
                address: transfer.sender,
                resources: .init(energy: estimate.energy, bandwidth: estimate.bandwidth),
                instantFeePayment: instantFeePayment
            )
        } catch {
            Log.multichainSwap.w(
                "relayed tron swap failed",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            throw .broadcastFailed(
                payloadId: payloadId,
                kind: .unknown,
                reason: "relay rejected the tron swap: \(error.localizedDescription)"
            )
        }
    }

    /// The fee transfer is signed while nothing has been handed over yet, so a wallet that can no
    /// longer fund it fails here rather than after the swap has been relayed.
    func instantFeePayment(
        _ quote: GramQuote,
        wallet: Wallet,
        mnemonic: CoreMnemonic,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> TronUSDTTransactionSender.InstantFeePayment {
        do {
            return try await tonFeePaymentBuilder.build(
                wallet: wallet,
                tonFeeAmount: quote.amountNano,
                tonFeeAddress: quote.feeAddress,
                signHandler: { transferData, wallet throws(TransactionConfirmationError) in
                    try await signedTonFeeTransfer(
                        transferData: transferData,
                        wallet: wallet,
                        mnemonic: mnemonic
                    )
                }
            )
        } catch {
            Log.multichainSwap.w(
                "gram instant fee payment failed",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            // The builder's only error is the balance check it makes against a fresh balance.
            let isShortage = error is TronUSDTTonFeePaymentBuilder.Error
            throw .preparationFailed(
                kind: isShortage ? .insufficientBalance : .internalError,
                reason: "failed to pay the gram instant fee of swap payload \(payloadId): \(error.localizedDescription)"
            )
        }
    }

    func signedTonFeeTransfer(
        transferData: TransferData,
        wallet: Wallet,
        mnemonic: CoreMnemonic
    ) async throws(TransactionConfirmationError) -> SignedTransactions {
        do {
            let keyPair = try mnemonic.toKeyPair()
            let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
                .createUnsignedWalletTransfer(wallet: wallet)
            let signed = try TransferSigner.signWalletTransfer(
                walletTransfer,
                wallet: wallet,
                seqno: transferData.seqno,
                signer: WalletTransferSecretKeySigner(secretKey: keyPair.privateKey.data)
            )
            return try SignedTransactions(boc: signed.toBoc().base64EncodedString())
        } catch {
            throw .failedToSign(
                message: "failed to sign the gram instant fee: \(error.localizedDescription)"
            )
        }
    }

    func mnemonic(
        wallet: Wallet,
        payloadId: String,
        passcodeProvider: () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> CoreMnemonic {
        guard let passcode = await passcodeProvider() else {
            throw .canceled
        }
        do {
            return try await mnemonicAccess.getMnemonic(wallet: wallet, passcode: passcode)
        } catch {
            Log.multichainSwap.w(
                "relayed tron swap unlock failed",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            throw .signingFailed(
                payloadId: payloadId,
                kind: .signInternalError,
                reason: "failed to unlock the wallet of a relayed tron swap: \(error.localizedDescription)"
            )
        }
    }

    func signedTransaction(
        _ transfer: RelayedTransfer,
        wallet: Wallet,
        mnemonic: CoreMnemonic,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> Transaction {
        do {
            let transaction: Transaction
            switch transfer.asset {
            case .usdt:
                transaction = try await tronUsdtApi.getSendTransaction(
                    address: transfer.sender,
                    method: TransferMethod(to: transfer.recipient, amount: transfer.amount)
                )
            case .trx:
                transaction = try await tronUsdtApi.getNativeTransferTransaction(
                    from: transfer.sender,
                    to: transfer.recipient,
                    amountSun: transfer.amount
                )
            }
            let extended = try transaction.extendingExpiration(byMilliseconds: 600_000)
            let privateKey = try tronPrivateKey(wallet: wallet, mnemonic: mnemonic)
            var signed = extended
            signed.signature = try Signer()
                .sign(hash: extended.signingDigest(), privateKey: privateKey)
                .hexString()
            return signed
        } catch {
            Log.multichainSwap.w(
                "relayed tron swap signing failed",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            throw .signingFailed(
                payloadId: payloadId,
                kind: .signInternalError,
                reason: "failed to sign a relayed tron swap: \(error.localizedDescription)"
            )
        }
    }

    /// A multichain wallet keeps its TRON key on the BIP39 branch; a wallet imported from a TON
    /// mnemonic derives it from that phrase instead, exactly as the USDT send does.
    func tronPrivateKey(wallet: Wallet, mnemonic: CoreMnemonic) throws -> TronSwift.PrivateKey {
        guard wallet.isMultichain, mnemonic.type == .bip39 else {
            return try TonTron.derivedKeyPair(
                tonMnemonic: mnemonic.mnemonicWords,
                index: 0
            ).privateKey
        }
        return try TronSwift.PrivateKey(
            data: chainKitService.tronPrivateKey(
                mnemonic: mnemonic.mnemonicWords.joined(separator: " ")
            ),
            chainCode: Data()
        )
    }
}
