import BigInt
import Foundation
import OperationReviewModels
import TKLogging
import TronSwift

@frozen public enum TronTransferSignError: Error {
    case incorrectWalletKind
    case cancelled
    case failedToSign(
        message: String?
    )
}

public final class TronUSDTTransactionConfirmationController: TransactionConfirmationController {
    @frozen public enum Error: Swift.Error {
        case tronAddressIsNotAvailable
    }

    public var tronSignHandler: ((TronSwift.TxID, Wallet) async throws(TronTransferSignError) -> TronSwift.SignedTxID)?
    public var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?

    public func setLoading() {
        updateState {
            $0.extraState = .loading
        }
    }

    public func getModel() -> TransactionConfirmationModel {
        let currentState = state
        let isMax = amount > 0 && amount == balance
        let amountItem: TransactionConfirmationModel.Amount.Item = switch token {
        case .usdt: .tronUSDT
        case .trx: .tronTRX
        }
        let transfer: TransactionConfirmationModel.Transaction.Transfer = switch token {
        case .usdt: .tronUSDT
        case .trx: .tronTRX
        }
        return TransactionConfirmationModel(
            wallet: wallet,
            recipient: nil,
            recipientAddress: recipientDisplayAddress ?? recipient.base58,
            transaction: .transfer(transfer),
            amount: .init(token: amountItem, value: amount),
            extraState: currentState.extraState,
            extraOptions: currentState.extraOptions,
            availableExtraTypes: currentState.availableTypes,
            isMax: isMax,
            totalFee: totalFee
        )
    }

    public func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {
        guard feeOptionsResolver.canSelect(extraType: extraType) else {
            return
        }
        updateState {
            $0.prefer(extraType)
        }
    }

    func resetAutomaticFeePreference() {
        updateState { $0.preferredExtraType = nil }
    }

    public func emulate() async -> Result<Void, TransactionConfirmationError> {
        do {
            guard let address = resolvedSenderAddress else {
                throw Error.tronAddressIsNotAvailable
            }

            let estimate = switch token {
            case .usdt:
                try await tronUsdtApi.estimateTransferFees(
                    wallet: wallet,
                    address: address,
                    method: TransferMethod(
                        to: recipient,
                        amount: amount
                    )
                )
            case .trx:
                try await tronUsdtApi.estimateNativeTransferFees(
                    wallet: wallet,
                    from: address,
                    to: recipient,
                    amountSun: amount
                )
            }

            let resolvedFees = feeOptionsResolver.resolve(
                estimate: estimate,
                wallet: wallet,
                preferredExtraType: state.preferredExtraType,
                requiresSelfPaidTRX: token == .trx
            )
            applyResolvedFees(resolvedFees)
            return .success(())
        } catch {
            Log.tron.w("TRON \(token.symbol) fee estimate failed", extraInfo: [
                "wallet": maskedSenderAddress,
                "error": TronSendErrorMessage.logDescription(for: error),
            ])
            return .failure(.failedToCalculateFee())
        }
    }

    public func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        await sendTransaction(consent: .refuse)
    }

    public func sendTransaction(consent: OperationConsent) async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        guard let address = resolvedSenderAddress else {
            return .failure(failure(stage: "resolve address", error: Error.tronAddressIsNotAvailable))
        }
        let currentState = state
        var stage = "build transaction"
        do {
            let txID = try await TronExpirationRetry.run(
                isEnabled: feeOptionsResolver.isTRXType(currentState.selectedExtraType)
            ) {
                stage = "build transaction"
                let transaction = switch self.token {
                case .usdt:
                    try await self.tronUsdtApi.getSendTransaction(
                        address: address,
                        method: TransferMethod(to: self.recipient, amount: self.amount)
                    )
                case .trx:
                    try await self.tronUsdtApi.getNativeTransferTransaction(
                        from: address,
                        to: self.recipient,
                        amountSun: self.amount
                    )
                }
                stage = "extend expiration"
                let extendedTransaction = try transaction.extendingExpiration(byMilliseconds: 600_000)
                stage = "review"
                try await self.clear(extendedTransaction, from: address, consent: consent)
                stage = "sign"
                let signedTransaction = try await self.sign(transaction: extendedTransaction)
                stage = "instant fee"
                let instantFeePayment = try await self.makeInstantFeePaymentIfNeeded(currentState: currentState)
                stage = "send"
                try await self.transactionSender.send(
                    signedTransaction: signedTransaction,
                    selectedExtraType: currentState.selectedExtraType,
                    wallet: self.wallet,
                    address: address,
                    resources: currentState.resources,
                    instantFeePayment: instantFeePayment
                )
                return signedTransaction.txID
            }
            return .success(
                .chain(
                    .tron,
                    wallet: wallet,
                    txHashes: [txID],
                    activityType: .send
                )
            )
        } catch {
            return .failure(failure(stage: stage, error: error))
        }
    }

    private func failure(stage: String, error: Swift.Error) -> TransactionConfirmationError {
        if error is TronExpirationRetry.Expired {
            return .multichainTransactionFailure(.operationExpired)
        }
        if let confirmationError = error as? TransactionConfirmationError, confirmationError.isCancel {
            return confirmationError
        }
        Log.tron.e("TRON \(token.symbol) send failed at \(stage)", extraInfo: [
            "wallet": maskedSenderAddress,
            "error": TronSendErrorMessage.logDescription(for: error),
        ])
        return .failedToSendTransaction(
            message: TronSendErrorMessage.logDescription(for: error).redactingAddresses,
            localizedMessage: TronSendErrorMessage.userMessage(for: error)
        )
    }

    @Atomic private var state = TronUSDTTransactionConfirmationState()

    private var totalFee: BigInt = 0

    private let wallet: Wallet
    private let token: TronToken
    private let recipient: TronRecipient
    private let amount: BigUInt
    private let recipientDisplayAddress: String?
    private let balance: BigUInt
    private let senderAddress: TronSwift.Address?
    private let tronUsdtApi: TronUSDTAPI
    private let feeOptionsResolver: TronUSDTFeeOptionsResolver
    private let transactionSender: TronUSDTTransactionSender
    private let tonFeePaymentBuilder: TronUSDTTonFeePaymentBuilder
    private let gate: OperationGate
    /// Signs in place of `tronSignHandler` when the wallet is a hardware one.
    private let deviceSigner: DeviceTransferSigner?
    private let now: () -> Date

    init(
        wallet: Wallet,
        token: TronToken,
        recipient: TronRecipient,
        amount: BigUInt,
        balance: BigUInt,
        senderAddress: TronSwift.Address? = nil,
        recipientDisplayAddress: String? = nil,
        tronUsdtApi: TronUSDTAPI,
        sendService: SendService,
        balanceService: BalanceService,
        configuration: Configuration,
        gate: OperationGate,
        deviceSigner: DeviceTransferSigner? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.wallet = wallet
        self.token = token
        self.recipient = recipient
        self.amount = amount
        self.recipientDisplayAddress = recipientDisplayAddress
        self.balance = balance
        self.senderAddress = senderAddress
        self.tronUsdtApi = tronUsdtApi
        self.gate = gate
        self.deviceSigner = deviceSigner
        self.now = now

        let feeOptionsResolver = TronUSDTFeeOptionsResolver(configuration: configuration)
        self.feeOptionsResolver = feeOptionsResolver
        transactionSender = TronUSDTTransactionSender(
            tronUsdtApi: tronUsdtApi,
            feeOptionsResolver: feeOptionsResolver
        )
        tonFeePaymentBuilder = TronUSDTTonFeePaymentBuilder(
            sendService: sendService,
            balanceService: balanceService
        )
    }

    private var resolvedSenderAddress: TronSwift.Address? {
        senderAddress ?? wallet.tron?.address
    }

    private var maskedSenderAddress: String {
        resolvedSenderAddress?.base58.pretty.masked ?? "unavailable"
    }

    /// The gate on the transaction about to be signed. A decline is the user's cancellation, which the
    /// retry never repeats and the failure log passes over; what could not be reviewed fails the send.
    private func clear(_ transaction: Transaction, from sender: TronSwift.Address, consent: OperationConsent) async throws {
        let wasLive = isLive(transaction)
        do throws(OperationRefusal) {
            try await gate.clear(.ask, consent: consent) {
                try [.tronPrebuild(
                    transaction,
                    account: ChainKitOperationSender.account(of: signingAddress(sender), holding: token.assetDetails),
                    intent: .send(amount, of: token.assetDetails, to: recipient.base58)
                )]
            }
        } catch .declined {
            throw TransactionConfirmationError.cancelledByUser
        }
        // The user can read the review past the expiration, and the chain would refuse what is signed
        // then. One the device's clock had expired already is left to the chain, as it always was.
        guard !wasLive || isLive(transaction) else {
            throw TronExpirationRetry.Expired()
        }
    }

    private func isLive(_ transaction: Transaction) -> Bool {
        transaction.expiresAt.timeIntervalSince(now()) > Transaction.relayLead
    }

    /// The address that signs, with the key a multichain wallet stored for it; a legacy wallet stored none.
    private func signingAddress(_ sender: TronSwift.Address) -> MultichainWalletAddress {
        wallet.multichainWalletState?.addresses.first { $0.chain == .tron && $0.address == sender.base58 }
            ?? MultichainWalletAddress(chain: .tron, address: sender.base58)
    }

    private func sign(transaction: Transaction) async throws -> Transaction {
        let signature = if let deviceSigner {
            try await deviceSignature(transaction: transaction, device: deviceSigner)
        } else {
            try await signedTronTransaction(txID: transaction.signingDigest())
        }

        var signedTransaction = transaction
        signedTransaction.signature = signature.hexString()
        return signedTransaction
    }

    private func applyResolvedFees(_ resolvedFees: TronUSDTFeeOptionsResolver.Result) {
        updateState {
            $0.availableTypes = resolvedFees.availableTypes
            $0.extraOptions = resolvedFees.extraOptions
            $0.preferredExtraType = resolvedFees.selectedType
            $0.extraState = .extra(resolvedFees.selectedExtra)
            $0.resources = resolvedFees.resources
            $0.tonFeeAddress = resolvedFees.tonFeeAddress
        }
    }

    private func makeInstantFeePaymentIfNeeded(
        currentState: TronUSDTTransactionConfirmationState
    ) async throws -> TronUSDTTransactionSender.InstantFeePayment? {
        guard currentState.selectedExtraType == .default else {
            return nil
        }

        guard case let .extra(extra) = currentState.extraState,
              case let .default(tonFeeAmount) = extra.value,
              let tonFeeAddress = currentState.tonFeeAddress
        else {
            throw TransactionConfirmationError.failedToCalculateFee()
        }

        let feeSigner: OperationGate.TonSigning? = if let signHandler {
            gate.clearing(signHandler, account: ChainKitOperationSender.tonAccount, intent: .send(tonFeeAmount, of: .gram, to: nil))
        } else {
            nil
        }
        return try await tonFeePaymentBuilder.build(
            wallet: wallet,
            tonFeeAmount: tonFeeAmount,
            tonFeeAddress: tonFeeAddress,
            signHandler: feeSigner
        )
    }

    private func updateState(_ update: (inout TronUSDTTransactionConfirmationState) -> Void) {
        var currentState = state
        update(&currentState)
        state = currentState
    }

    private func deviceSignature(
        transaction: Transaction,
        device: DeviceTransferSigner
    ) async throws(TransactionConfirmationError) -> TronSwift.SignedTxID {
        guard let sender = resolvedSenderAddress else {
            throw .failedToSign(message: "no tron sender to check the device signature against")
        }
        do {
            return try await DeviceTransactionSigner.signTronTransaction(transaction, sender: sender.base58, device: device.tron)
        } catch {
            if case .canceled = error {
                throw .cancelledByUser
            }
            throw .multichainTransactionFailure(error)
        }
    }

    private func signedTronTransaction(
        txID: TronSwift.TxID
    ) async throws(TransactionConfirmationError) -> TronSwift.SignedTxID {
        guard let tronSignHandler else {
            throw .failedToSign(message: "missing tron handler")
        }
        do {
            return try await tronSignHandler(txID, wallet)
        } catch {
            switch error {
            case .cancelled:
                throw .cancelledByUser
            default:
                throw .failedToSign(
                    message: "failed to sign tron transaction due to error: \(error.analyticsReason)"
                )
            }
        }
    }
}

private extension TronToken {
    /// The token as chain-kit and a send's intent name it.
    var assetDetails: MultichainAssetDetails {
        let token = Token.tron(self)
        return MultichainAssetDetails(assetId: token.assetId(network: .mainnet), name: token.name, symbol: symbol, decimals: fractionDigits, image: "")
    }
}
