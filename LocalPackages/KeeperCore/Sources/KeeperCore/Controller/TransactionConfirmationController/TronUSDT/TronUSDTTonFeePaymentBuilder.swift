import BigInt
import Foundation
import TonSwift

public struct TronUSDTTonFeePaymentBuilder {
    enum Error: Swift.Error {
        case insufficientTONBalance(required: BigUInt, balance: BigUInt)
    }

    private static let identifyingComment = "Tron gas fee"
    private static let tonTransferOwnFeeNano = BigUInt(10_000_000)

    public static func requiredTonBalance(for tonFeeAmount: BigUInt) -> BigUInt {
        tonFeeAmount + tonTransferOwnFeeNano
    }

    private let sendService: SendService
    private let balanceService: BalanceService

    init(sendService: SendService, balanceService: BalanceService) {
        self.sendService = sendService
        self.balanceService = balanceService
    }

    func build(
        wallet: Wallet,
        tonFeeAmount: BigUInt,
        tonFeeAddress: String,
        signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?
    ) async throws -> TronUSDTTransactionSender.InstantFeePayment {
        let requiredTonBalance = Self.requiredTonBalance(for: tonFeeAmount)
        let tonBalance = try await loadTONBalance(wallet: wallet)
        guard tonBalance >= requiredTonBalance else {
            throw Error.insufficientTONBalance(required: requiredTonBalance, balance: tonBalance)
        }

        let seqno = try await sendService.loadSeqno(wallet: wallet)
        let timeout = await sendService.getTimeoutSafely(wallet: wallet, TTL: DEFAULT_TTL)
        let parsedTonFeeAddress = try Address.parse(tonFeeAddress)

        let transferData = TransferData(
            transfer: .ton(
                TransferData.Ton(
                    amount: tonFeeAmount,
                    isMax: false,
                    recipient: parsedTonFeeAddress,
                    comment: Self.identifyingComment
                )
            ),
            wallet: wallet,
            messageType: .ext,
            seqno: seqno,
            timeout: timeout
        )

        guard let signHandler else {
            throw TransactionConfirmationError.failedToCalculateFee
        }

        let signedTonFeeTx = try await signedTonFeeTransaction(
            transferData: transferData,
            wallet: wallet,
            signHandler: signHandler
        )

        return try TronUSDTTransactionSender.InstantFeePayment(
            instantFeeTx: signedTonFeeTx,
            userPublicKey: wallet.publicKey.data.base64EncodedString()
        )
    }

    private func loadTONBalance(wallet: Wallet) async throws -> BigUInt {
        // Load a fresh balance so a just-completed TON top-up isn't missed on the send path; fall
        // back to the cached balance only if the network load fails.
        if let balance = try? await balanceService.loadWalletBalance(
            wallet: wallet,
            currency: .USD,
            includingTransferFees: true
        ) {
            return BigUInt(max(balance.balance.tonBalance.amount, 0))
        }

        let cachedBalance = try balanceService.getBalance(wallet: wallet).balance.tonBalance.amount
        return BigUInt(max(cachedBalance, 0))
    }

    private func signedTonFeeTransaction(
        transferData: TransferData,
        wallet: Wallet,
        signHandler: (TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions
    ) async throws(TransactionConfirmationError) -> String {
        let signed = try await signHandler(transferData, wallet)
        guard let firstSignedTransaction = signed.first else {
            throw TransactionConfirmationError.failedToSign(
                message: "signed transaction list if empty"
            )
        }
        return firstSignedTransaction
    }
}
