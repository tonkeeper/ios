import Foundation
import TonSwift
import BigInt
import TonAPI

final class StakingDepositTransactionConfirmationController: TransactionConfirmationController {
  func getModel() -> TransactionConfirmationModel {
    createModel()
  }
  
  func emulate() async -> Result<Void, TransactionConfirmationError> {
    do {
      let boc = try await createEmulateBoc()
      let transactionInfo = try await sendService.loadTransactionInfo(boc: boc, wallet: wallet)
      updateFee(transactionInfo: transactionInfo)
      return .success(())
    } catch {
      fee = .value(nil, converted: nil)
      return .failure(.failedToCalculateFee)
    }
  }
  
  func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
    do {
      let transactionBoc = try await createSignedBoc()
      try await sendService.sendTransaction(boc: transactionBoc, wallet: wallet)
      return .success(())
    } catch TransactionConfirmationError.failedToSign {
      return .failure(.failedToSign)
    } catch {
      return .failure(.failedToSendTransaction)
    }
  }
  
  public var signHandler: ((TransferMessageBuilder, Wallet) async throws -> String?)?

  private var fee: TransactionConfirmationModel.Fee = .loading
  
  private let wallet: Wallet
  private let stakingPool: StackingPoolInfo
  private let amount: BigUInt
  private let isMax: Bool
  private let isCollect: Bool
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let balanceStore: BalanceStore
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  
  init(wallet: Wallet,
       stakingPool: StackingPoolInfo,
       amount: BigUInt,
       isMax: Bool,
       isCollect: Bool,
       sendService: SendService,
       blockchainService: BlockchainService,
       balanceStore: BalanceStore,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore) {
    self.wallet = wallet
    self.stakingPool = stakingPool
    self.amount = amount
    self.isMax = isMax
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
          flow: .deposit
        )
      ),
      amount: getAmountValue(),
      fee: fee
    )
  }
  
  private func createEmulateBoc() async throws -> String {
    let transferMessageBuilder = try await createTransferMessageBuilder()
    return try await transferMessageBuilder.createBoc { transfer in
      try await transferMessageBuilder.externalSign(wallet: wallet) { transfer in
        try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
      }
    }
  }
  
  private func createSignedBoc() async throws -> String {
    let transferMessageBuilder = try await createTransferMessageBuilder()
    return try await transferMessageBuilder.createBoc { transfer in
      return try await signTransfer(transfer)
    }
  }
  
  private func createTransferMessageBuilder() async throws -> TransferMessageBuilder {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)

    let transferMessageBuilder = TransferMessageBuilder(
      transferData: .stake(
        .deposit(
          TransferData.StakeDeposit(
            seqno: seqno,
            pool: stakingPool,
            amount: updateAmount(amount: amount),
            isMax: isMax,
            isBouncable: true,
            timeout: timeout
          )
        )
      )
    )
    return transferMessageBuilder
  }
  
  private func updateFee(transactionInfo: MessageConsequences) {
    let fee = BigUInt(abs(transactionInfo.event.extra))
    let extraFee = fee + stakingPool.implementation.extraFee
    
    var convertedFee: TransactionConfirmationModel.Amount?
    let currency = currencyStore.getState()
    if let rates = ratesStore.getState().first(where: { $0.currency == currency }) {
      let rateConverter = RateConverter()
      let converted = rateConverter.convert(
        amount: extraFee,
        amountFractionLength: TonInfo.fractionDigits,
        rate: rates
      )
      convertedFee = TransactionConfirmationModel.Amount(
        value: converted.amount,
        decimals: converted.fractionLength,
        item: .currency(currency)
      )
    }
    
    self.fee = .value(
      TransactionConfirmationModel.Amount(
        value: extraFee,
        decimals: TonInfo.fractionDigits,
        item: .currency(.TON)
      ),
      converted: convertedFee
    )
  }
  
  private func getAmountValue() -> (amount: TransactionConfirmationModel.Amount, converted: TransactionConfirmationModel.Amount?) {
    let currency = currencyStore.getState()
    var convertedAmount: TransactionConfirmationModel.Amount?
    if let rates = ratesStore.getState().first(where: { $0.currency == currency }) {
      let rateConverter = RateConverter()
      let converted = rateConverter.convert(
        amount: amount,
        amountFractionLength: TonInfo.fractionDigits,
        rate: rates
      )
      convertedAmount = TransactionConfirmationModel.Amount(
        value: converted.amount,
        decimals: converted.fractionLength,
        item: .currency(currency)
      )
    }
    return (
      TransactionConfirmationModel.Amount(
        value: amount,
        decimals: TonInfo.fractionDigits,
        item: .currency(.TON)
      ),
      convertedAmount
    )
  }
  
  private func updateAmount(amount: BigUInt) -> BigUInt {
    return amount + stakingPool.implementation.depositExtraFee
  }
  
  func signTransfer(_ transferBuilder: TransferMessageBuilder) async throws -> String {
    guard let signHandler,
          let signedData = try await signHandler(transferBuilder, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
