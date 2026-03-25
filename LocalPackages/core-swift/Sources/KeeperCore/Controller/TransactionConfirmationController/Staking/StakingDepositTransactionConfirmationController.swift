import BigInt
import Foundation
import TonAPI
import TonSwift

final class StakingDepositTransactionConfirmationController: TransactionConfirmationController {
    func getModel() -> TransactionConfirmationModel {
        createModel()
    }

    func setLoading() {
        extraState = .loading
    }

    func emulate() async -> Result<Void, TransactionConfirmationError> {
        do {
            let boc = try await createEmulateBoc()
            let transactionInfo = try await sendService.loadTransactionInfo(
                boc: boc,
                wallet: wallet,
                params: nil,
                currency: nil
            )
            updateFee(transactionInfo: transactionInfo)
            return .success(())
        } catch {
            extraState = .none
            return .failure(.failedToCalculateFee)
        }
    }

    func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
        guard let signHandler else {
            return .failure(.cancelledByUser)
        }
        let transferData: TransferData
        do {
            transferData = try await createTransferData()
        } catch {
            return .failure(.failedToSendTransaction())
        }

        let signedTransactions: SignedTransactions
        do {
            signedTransactions = try await signHandler(transferData, wallet)
        } catch {
            return .failure(error)
        }

        do {
            if signedTransactions.isEmpty {
                return .failure(.failedToSendTransaction())
            }

            if signedTransactions.count == 1 {
                try await sendService.sendTransaction(boc: signedTransactions[0], wallet: wallet)
            } else {
                try await sendService.sendTransactions(batch: signedTransactions, wallet: wallet)
            }
            return .success(())
        } catch {
            return .failure(.failedToSendTransaction())
        }
    }

    var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?

    private var extraState: TransactionConfirmationModel.ExtraState = .loading
    private var totalFee: BigInt = 0

    private let wallet: Wallet
    private let stakingPool: StackingPoolInfo
    private let amount: BigUInt
    private let isCollect: Bool
    private let sendService: SendService
    private let blockchainService: BlockchainService
    private let tonBalanceService: TonBalanceService
    private let ratesStore: TonRatesStore
    private let currencyStore: CurrencyStore

    init(
        wallet: Wallet,
        stakingPool: StackingPoolInfo,
        amount: BigUInt,
        isCollect: Bool,
        sendService: SendService,
        blockchainService: BlockchainService,
        tonBalanceService: TonBalanceService,
        ratesStore: TonRatesStore,
        currencyStore: CurrencyStore
    ) {
        self.wallet = wallet
        self.stakingPool = stakingPool
        self.amount = amount
        self.isCollect = isCollect
        self.sendService = sendService
        self.blockchainService = blockchainService
        self.tonBalanceService = tonBalanceService
        self.ratesStore = ratesStore
        self.currencyStore = currencyStore
    }

    private func createModel() -> TransactionConfirmationModel {
        return TransactionConfirmationModel(
            wallet: wallet,
            recipient: stakingPool.implementation.name,
            recipientAddress: nil,
            transaction: .staking(
                TransactionConfirmationModel.Transaction.Staking(
                    pool: stakingPool,
                    flow: .deposit
                )
            ),
            amount: getAmountValue(),
            extraState: extraState,
            availableExtraTypes: [.default],
            totalFee: totalFee
        )
    }

    private func createEmulateBoc() async throws -> String {
        let transferData = try await createTransferData()
        let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
            .createUnsignedWalletTransfer(
                wallet: wallet
            )
        let signed = try TransferSigner.signWalletTransfer(
            walletTransfer,
            wallet: wallet,
            seqno: transferData.seqno,
            signer: WalletTransferEmptyKeySigner()
        )

        return try signed.toBoc().hexString()
    }

    private func createTransferData() async throws -> TransferData {
        let seqno = try await sendService.loadSeqno(wallet: wallet)
        let timeout = await sendService.getTimeoutSafely(wallet: wallet, TTL: DEFAULT_TTL)
        let isMax = await {
            do {
                let balance = try await tonBalanceService.loadBalance(wallet: wallet)
                return amount == BigUInt(integerLiteral: UInt64(balance.amount))
            } catch {
                return false
            }
        }()

        return TransferData(
            transfer: .stake(
                .deposit(
                    TransferData.StakeDeposit(
                        pool: stakingPool,
                        amount: updateAmount(amount: amount),
                        isMax: isMax,
                        isBouncable: true
                    )
                )
            ),
            wallet: wallet,
            messageType: .ext,
            seqno: seqno,
            timeout: timeout
        )
    }

    private func updateFee(transactionInfo: MessageConsequences) {
        let isRefund = transactionInfo.event.extra > 0
        let extra = BigUInt(abs(transactionInfo.event.extra))
        let withExtraFee = isRefund ? stakingPool.implementation.extraFee : extra + stakingPool.implementation.extraFee

        totalFee = BigInt(transactionInfo.trace.transaction.totalFees)

        self.extraState = .extra(
            TransactionConfirmationModel.Extra(
                value: .default(amount: withExtraFee),
                kind: isRefund ? .refund : .fee
            )
        )
    }

    private func getAmountValue() -> TransactionConfirmationModel.Amount {
        return
            TransactionConfirmationModel.Amount(
                token: .ton(.ton),
                value: amount
            )
    }

    private func updateAmount(amount: BigUInt) -> BigUInt {
        return amount + stakingPool.implementation.depositExtraFee
    }
}
