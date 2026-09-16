import BigInt
import Foundation
import TKLogging
import TronSwift

public enum TronTransferSignError: Error {
    case incorrectWalletKind
    case cancelled
    case failedToSign(
        message: String?
    )
}

public final class TronUSDTTransactionConfirmationController: TransactionConfirmationController {
    public enum Error: Swift.Error {
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
            $0.preferredExtraType = extraType
        }
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
            return .failure(.failedToCalculateFee)
        }
    }

    public func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
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
        if let confirmationError = error as? TransactionConfirmationError, confirmationError.isCancel {
            return confirmationError
        }
        Log.tron.e("TRON \(token.symbol) send failed at \(stage)", extraInfo: [
            "wallet": maskedSenderAddress,
            "error": TronSendErrorMessage.logDescription(for: error),
        ])
        return .failedToSendTransaction(
            message: TronSendErrorMessage.userMessage(for: error)
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
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.token = token
        self.recipient = recipient
        self.amount = amount
        self.recipientDisplayAddress = recipientDisplayAddress
        self.balance = balance
        self.senderAddress = senderAddress
        self.tronUsdtApi = tronUsdtApi

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

    private func sign(transaction: Transaction) async throws -> Transaction {
        let signature = try await signedTronTransaction(txID: transaction.signingDigest())

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
            throw TransactionConfirmationError.failedToCalculateFee
        }

        return try await tonFeePaymentBuilder.build(
            wallet: wallet,
            tonFeeAmount: tonFeeAmount,
            tonFeeAddress: tonFeeAddress,
            signHandler: signHandler
        )
    }

    private func updateState(_ update: (inout TronUSDTTransactionConfirmationState) -> Void) {
        var currentState = state
        update(&currentState)
        state = currentState
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
                    message: "failed to sign tron transaction due to error: \(error.localizedDescription)"
                )
            }
        }
    }
}
