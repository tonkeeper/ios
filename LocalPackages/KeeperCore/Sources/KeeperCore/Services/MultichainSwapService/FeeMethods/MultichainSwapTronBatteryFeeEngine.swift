import BigInt
import Foundation
import TKLogging
import TronSwift

/// Pays a TRON swap with battery charges. A TRON route is a transfer of the source asset to the
/// aggregator's deposit address, so the relayer signs and broadcasts the same transaction the wallet
/// would have sent itself, and the charges come from the battery's own TRON estimate.
struct MultichainSwapTronBatteryFeeEngine: MultichainSwapBatteryFeeEngine {
    private let tronUsdtApi: TronUSDTAPI
    private let transactionSender: TronUSDTTransactionSender
    private let batteryChargesReader: BatteryChargesReader
    private let configuration: Configuration
    private let chainKitService: ChainKitService
    private let mnemonicAccess: MnemonicAccess

    init(
        tronUsdtApi: TronUSDTAPI,
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
        batteryChargesReader = BatteryChargesReader(
            batteryService: batteryService,
            batteryCalculation: batteryCalculation
        )
        self.configuration = configuration
        self.chainKitService = chainKitService
        self.mnemonicAccess = mnemonicAccess
    }

    let chain = MultichainChain.tron

    func option(context: MultichainSwapFeeContext) async -> MultichainSwapFeeOption? {
        guard let transfer = await relayedTransfer(context: context),
              let estimate = await estimate(transfer, wallet: context.wallet)
        else {
            return nil
        }
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
        return MultichainSwapBatteryFeeRules.option(
            charges: estimate.requiredBatteryCharges,
            excessCharges: nil,
            availableCharges: availableCharges
        )
    }

    func send(
        context: MultichainSwapFeeContext,
        confirmedCharges: Int,
        passcodeProvider: @escaping () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> String {
        let payloadId = context.payloadId
        guard let transfer = await relayedTransfer(context: context) else {
            throw .internal(reason: "battery cannot pay for swap payload \(payloadId)")
        }
        let availableCharges = await batteryChargesReader.availableCharges(wallet: context.wallet)
        try MultichainSwapBatteryFeeRules.requireCharges(
            confirmedCharges,
            available: availableCharges,
            payloadId: payloadId
        )
        // The relayer is billed for the resources it burns, so they are re-quoted against the chain
        // as it is now rather than as the confirmation screen saw it.
        guard let estimate = await estimate(transfer, wallet: context.wallet) else {
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
        let signedTransaction = try await signedTransaction(
            transfer,
            wallet: context.wallet,
            payloadId: payloadId,
            passcodeProvider: passcodeProvider
        )
        do {
            try await transactionSender.send(
                signedTransaction: signedTransaction,
                selectedExtraType: .battery,
                wallet: context.wallet,
                address: transfer.sender,
                resources: .init(energy: estimate.energy, bandwidth: estimate.bandwidth),
                instantFeePayment: nil
            )
        } catch {
            Log.multichainSwap.w(
                "battery tron swap relay failed",
                error: error,
                extraInfo: ["payloadId": payloadId]
            )
            throw .broadcastFailed(
                payloadId: payloadId,
                kind: .unknown,
                reason: "battery relay rejected the tron swap: \(error.localizedDescription)"
            )
        }
        return signedTransaction.txID
    }
}

private extension MultichainSwapTronBatteryFeeEngine {
    struct RelayedTransfer {
        let sender: TronSwift.Address
        let recipient: TronSwift.Address
        let amount: BigUInt
        let asset: MultichainSwapRelayedAsset.TronAsset
    }

    func relayedTransfer(context: MultichainSwapFeeContext) async -> RelayedTransfer? {
        guard case let .tron(transfer) = context.payload else {
            return nil
        }
        let isBatteryEnabled = await configuration.isBatteryEnable(network: context.wallet.network)
        let isBatterySendEnabled = await configuration.isBatterySendEnable(network: context.wallet.network)
        let isTRXOnlyRegion = configuration.isTRXOnlyRegion(network: context.wallet.network)
        guard case let .tron(asset) = MultichainSwapBatteryFeeRules.relayedAsset(
            wallet: context.wallet,
            sourceAsset: context.sourceAsset,
            requiresApproval: context.requiresApproval,
            isBatteryEnabled: isBatteryEnabled,
            isBatterySendEnabled: isBatterySendEnabled,
            isTRXOnlyRegion: isTRXOnlyRegion
        ),
            case let .multichain(state) = context.wallet.multichain,
            let senderAddress = state.address(for: .tron)
        else {
            Log.multichainSwap.i(
                "battery tron swap not offered",
                extraInfo: [
                    "payloadId": context.payloadId,
                    "sourceAsset": context.sourceAsset.asset.assetId,
                    "batteryEnabled": "\(isBatteryEnabled)",
                    "batterySendEnabled": "\(isBatterySendEnabled)",
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
                "battery tron swap option skipped: unusable addresses",
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
            Log.multichainSwap.w("battery tron swap fee estimation failed", error: error)
            return nil
        }
    }

    func signedTransaction(
        _ transfer: RelayedTransfer,
        wallet: Wallet,
        payloadId: String,
        passcodeProvider: () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> Transaction {
        guard let passcode = await passcodeProvider() else {
            throw .canceled
        }
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
            let privateKey = try await tronPrivateKey(wallet: wallet, passcode: passcode)
            var signed = extended
            signed.signature = try Signer()
                .sign(hash: extended.signingDigest(), privateKey: privateKey)
                .hexString()
            return signed
        } catch {
            Log.multichainSwap.w(
                "battery tron swap signing failed",
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
    func tronPrivateKey(wallet: Wallet, passcode: String) async throws -> TronSwift.PrivateKey {
        let mnemonic = try await mnemonicAccess.getMnemonic(wallet: wallet, passcode: passcode)
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
