import BigInt
import Foundation
import TonAPI
import TonSwift

final class StakingWithdrawTransactionConfirmationController: TransactionConfirmationController {
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

    @Atomic private var extraState: TransactionConfirmationModel.ExtraState = .loading
    @Atomic private var totalFee: BigInt = 0

    private let wallet: Wallet
    private let stakingPool: StackingPoolInfo
    private let amount: BigUInt
    private let isCollect: Bool
    private let sendService: SendService
    private let blockchainService: BlockchainService
    private let balanceStore: BalanceStore
    private let ratesStore: TonRatesStore
    private let currencyStore: CurrencyStore

    init(
        wallet: Wallet,
        stakingPool: StackingPoolInfo,
        amount: BigUInt,
        isCollect: Bool,
        sendService: SendService,
        blockchainService: BlockchainService,
        balanceStore: BalanceStore,
        ratesStore: TonRatesStore,
        currencyStore: CurrencyStore
    ) {
        self.wallet = wallet
        self.stakingPool = stakingPool
        self.amount = amount
        self.isCollect = isCollect
        self.sendService = sendService
        self.blockchainService = blockchainService
        self.balanceStore = balanceStore
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
                    flow: .withdraw(isCollect: isCollect)
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

        return TransferData(
            transfer: .stake(
                .withdraw(
                    TransferData.StakeWithdraw(
                        pool: stakingPool,
                        amount: convertAmount(amount: amount),
                        isBouncable: true,
                        jettonWalletAddress: { [blockchainService] wallet, jettonMasterAddress in
                            try await blockchainService.getWalletAddress(
                                jettonMaster: jettonMasterAddress?.toRaw() ?? "",
                                owner: wallet.address.toRaw(),
                                network: wallet.network
                            )
                        }
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

        self.totalFee = BigInt(transactionInfo.trace.transaction.totalFees)

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

    private func convertAmount(amount: BigUInt) -> BigUInt {
        guard stakingPool.implementation.type == .liquidTF else {
            return amount
        }

        guard let jettonMasterAddress = stakingPool.liquidJettonMaster else {
            return amount
        }

        guard let balance = balanceStore.getState()[wallet]?.walletBalance.balance,
              let jettonBalance = balance.jettonsBalance
              .first(where: { $0.item.jettonInfo.address == jettonMasterAddress }),
              let rate = jettonBalance.rates.first(where: { $0.key == .TON })?.value
        else {
            return 0
        }

        let rateConverter = RateConverter()
        return rateConverter.convertFromCurrency(
            amount: amount,
            amountFractionLength: TonInfo.fractionDigits,
            rate: rate
        )
    }
}
