import BigInt
import Foundation
import TKCryptoKit
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
        let isMax = amount > 0 && amount == tronUSDTBalance
        return TransactionConfirmationModel(
            wallet: wallet,
            recipient: nil,
            recipientAddress: recipientDisplayAddress ?? recipient.base58,
            transaction: .transfer(.tronUSDT),
            amount: .init(token: .tronUSDT, value: amount),
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
            guard let address = wallet.tron?.address else {
                throw Error.tronAddressIsNotAvailable
            }

            let estimate = try await tronUsdtApi.estimateTransferFees(
                address: address,
                method: TransferMethod(
                    to: recipient,
                    amount: amount
                )
            )

            let resolvedFees = feeOptionsResolver.resolve(
                estimate: estimate,
                wallet: wallet,
                preferredExtraType: state.preferredExtraType
            )
            applyResolvedFees(resolvedFees)
            return .success(())
        } catch {
            return .failure(.failedToCalculateFee)
        }
    }

    public func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
        guard let address = wallet.tron?.address else {
            return .failure(
                .failedToSendTransaction(
                    message: "tron address is not available"
                )
            )
        }
        let signedTransaction: Transaction
        do {
            signedTransaction = try await makeSignedTransaction(address: address)
        } catch {
            return .failure(
                .failedToSendTransaction(
                    message: "failed to sign transaction due to error: \(error.localizedDescription)"
                )
            )
        }
        let currentState = state
        let instantFeePayment: TronUSDTTransactionSender.InstantFeePayment?
        do {
            instantFeePayment = try await makeInstantFeePaymentIfNeeded(currentState: currentState)
        } catch {
            return .failure(
                .failedToSendTransaction(
                    message: "failed to make instant fee due to error: \(error.localizedDescription)"
                )
            )
        }
        do {
            try await transactionSender.send(
                signedTransaction: signedTransaction,
                selectedExtraType: currentState.selectedExtraType,
                wallet: wallet,
                address: address,
                resources: currentState.resources,
                instantFeePayment: instantFeePayment
            )
        } catch {
            return .failure(
                .failedToSendTransaction(
                    message: "failed to send transaction due to error: \(error.localizedDescription)"
                )
            )
        }
        return .success(())
    }

    @Atomic private var state = TronUSDTTransactionConfirmationState()

    private var totalFee: BigInt = 0

    private let wallet: Wallet
    private let recipient: TronRecipient
    private let amount: BigUInt
    private let recipientDisplayAddress: String?
    private let tronUSDTBalance: BigUInt
    private let tronUsdtApi: TronUSDTAPI
    private let feeOptionsResolver: TronUSDTFeeOptionsResolver
    private let transactionSender: TronUSDTTransactionSender
    private let tonFeePaymentBuilder: TronUSDTTonFeePaymentBuilder

    init(
        wallet: Wallet,
        recipient: TronRecipient,
        amount: BigUInt,
        tronUSDTBalance: BigUInt,
        recipientDisplayAddress: String? = nil,
        tronUsdtApi: TronUSDTAPI,
        tonProofService: TonProofTokenService,
        sendService: SendService,
        balanceService: BalanceService,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.amount = amount
        self.recipientDisplayAddress = recipientDisplayAddress
        self.tronUSDTBalance = tronUSDTBalance
        self.tronUsdtApi = tronUsdtApi

        let feeOptionsResolver = TronUSDTFeeOptionsResolver(configuration: configuration)
        self.feeOptionsResolver = feeOptionsResolver
        transactionSender = TronUSDTTransactionSender(
            tronUsdtApi: tronUsdtApi,
            tonProofService: tonProofService,
            feeOptionsResolver: feeOptionsResolver
        )
        tonFeePaymentBuilder = TronUSDTTonFeePaymentBuilder(
            sendService: sendService,
            balanceService: balanceService
        )
    }

    private func makeSignedTransaction(address: Address) async throws -> Transaction {
        let method = TransferMethod(
            to: recipient,
            amount: amount
        )
        let transaction = try await tronUsdtApi.getSendTransaction(address: address, method: method)
        let extendedTransaction = try await tronUsdtApi.extendTransactionExpiration(
            transaction: transaction,
            expirationExtension: 600_000
        )
        let txID = SHA256.hash(data: Data(hex: extendedTransaction.rawDataHex))
        let signature = try await signedTronTransaction(txID: txID)

        var signedTransaction = extendedTransaction
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
