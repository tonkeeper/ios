import BigInt
import Foundation
import TonAPI
import TonSwift

final class TonTransferTransactionConfirmationController: TransactionConfirmationController {
    func getModel() -> TransactionConfirmationModel {
        createModel()
    }

    func setLoading() {
        extraState = .loading
    }

    func emulate() async -> Result<Void, TransactionConfirmationError> {
        do {
            let result = try await transferService.emulate(
                wallet: wallet,
                transfer: .ton(amount: amount, recipient: recipient, comment: comment)
            )
            self.emulationResult = result
            await updateFee(emulationResult: emulationResult)
            return .success(())
        } catch {
            self.emulationResult = nil
            await updateFee(emulationResult: nil)
            return .failure(.failedToCalculateFee)
        }
    }

    func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
        do {
            try await transferService.sendTransaction(
                wallet: wallet,
                transfer: .ton(amount: amount, recipient: recipient, comment: comment),
                transferType: emulationResult?.transferType ?? .default,
                signClosure: { [weak self, wallet] transferData -> Result<SignedTransactions, TransactionConfirmationError> in
                    guard let self else {
                        return .failure(.cancelledByUser)
                    }
                    return await signedTransactions(transferData: transferData, wallet: wallet)
                }
            )
            return .success(())
        } catch {
            if case let .secondOption(transactionError) = error,
               case .cancelledByUser = transactionError
            {
                return .failure(.cancelledByUser)
            }
            return .failure(
                .failedToSendTransaction(
                    message: error.localizedDescription
                )
            )
        }
    }

    var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?

    @Atomic private var emulationResult: TransferEmulationResult?
    @Atomic private var extraState: TransactionConfirmationModel.ExtraState = .loading
    private var totalFee: BigInt = 0

    private let wallet: Wallet
    private let recipient: TonRecipient
    private let amount: BigUInt
    private let comment: String?
    private let isMaxAmount: Bool
    private let recipientDisplayAddress: String?
    private let sendService: SendService
    private let blockchainService: BlockchainService
    private let ratesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let transferService: TransferService
    private let ratesService: RatesService

    init(
        wallet: Wallet,
        recipient: TonRecipient,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool,
        recipientDisplayAddress: String? = nil,
        sendService: SendService,
        blockchainService: BlockchainService,
        ratesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        transferService: TransferService,
        ratesService: RatesService
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.amount = amount
        self.comment = comment
        self.isMaxAmount = isMaxAmount
        self.recipientDisplayAddress = recipientDisplayAddress
        self.sendService = sendService
        self.blockchainService = blockchainService
        self.ratesStore = ratesStore
        self.currencyStore = currencyStore
        self.transferService = transferService
        self.ratesService = ratesService
    }

    private func createModel() -> TransactionConfirmationModel {
        return TransactionConfirmationModel(
            wallet: wallet,
            recipient: recipient.recipientAddress.name,
            recipientAddress: recipientDisplayAddress ?? recipient.recipientAddress.addressString,
            transaction: .transfer(.ton(isMaxAmount)),
            amount: getAmountValue(),
            extraState: extraState,
            comment: comment,
            availableExtraTypes: [.default],
            isMax: isMaxAmount,
            totalFee: totalFee
        )
    }

    private func updateFee(emulationResult: TransferEmulationResult?) async {
        guard let emulationResult else {
            extraState = .none
            return
        }
        let extra = emulationResult.extra

        let (amount, isRefund) = {
            switch extra.amount {
            case let .fee(amount):
                return (amount, false)
            case let .refund(amount):
                return (amount, true)
            }
        }()

        if let totalFee = emulationResult.transactionInfo?.trace.transaction.totalFees {
            self.totalFee = BigInt(totalFee)
        }

        self.extraState = .extra(
            TransactionConfirmationModel.Extra(
                value: .default(amount: amount),
                kind: isRefund ? .refund : .fee
            )
        )
    }

    private func getAmountValue() -> TransactionConfirmationModel.Amount {
        return TransactionConfirmationModel.Amount(
            token: .ton(.ton),
            value: amount
        )
    }

    private func signedTransactions(
        transferData: TransferData,
        wallet: Wallet
    ) async -> Result<SignedTransactions, TransactionConfirmationError> {
        guard let signHandler else {
            return .failure(.cancelledByUser)
        }
        let transactions: SignedTransactions
        do {
            transactions = try await signHandler(transferData, wallet)
        } catch {
            return .failure(error)
        }
        return .success(transactions)
    }
}
