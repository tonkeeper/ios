import Foundation
import TonSwift
import BigInt
import TonAPI

final class JettonTransferTransactionConfirmationController: TransactionConfirmationController {
  func getModel() -> TransactionConfirmationModel {
    createModel()
  }
  
  func emulate() async -> Result<Void, TransactionConfirmationError> {
    return .success(())
//    do {
//      let boc = try await createEmulateBoc()
//      let transactionInfo = try await sendService.loadTransactionInfo(boc: boc, wallet: wallet)
//      updateFee(transactionInfo: transactionInfo)
//      return .success(())
//    } catch {
//      fee = .value(nil, converted: nil)
//      return .failure(.failedToCalculateFee)
//    }
  }
  
  func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
    return .success(())
//    do {
//      let transactionBoc = try await createSignedBoc()
//      try await sendService.sendTransaction(boc: transactionBoc, wallet: wallet)
//      return .success(())
//    } catch TransactionConfirmationError.failedToSign {
//      return .failure(.failedToSign)
//    } catch {
//      return .failure(.failedToSendTransaction)
//    }
  }
  
  public var signHandler: ((TransferMessageBuilder, Wallet) async throws -> String?)?

  private var fee: TransactionConfirmationModel.Fee = .loading
  
  private let wallet: Wallet
  private let recipient: Recipient
  private let jettonItem: JettonItem
  private let amount: BigUInt
  private let comment: String?
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let balanceStore: BalanceStore
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  
  init(wallet: Wallet,
       recipient: Recipient,
       jettonItem: JettonItem,
       amount: BigUInt,
       comment: String?,
       sendService: SendService,
       blockchainService: BlockchainService,
       balanceStore: BalanceStore,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore) {
    self.wallet = wallet
    self.recipient = recipient
    self.jettonItem = jettonItem
    self.amount = amount
    self.comment = comment
    self.sendService = sendService
    self.blockchainService = blockchainService
    self.balanceStore = balanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
  }
  
  private func createModel() -> TransactionConfirmationModel {
    return TransactionConfirmationModel(
      wallet: wallet,
      recipient: recipient.recipientAddress.name,
      recipientAddress: recipient.recipientAddress.addressString,
      transaction: .transfer(.jetton(jettonItem.jettonInfo)),
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
    fatalError()
//    let seqno = try await sendService.loadSeqno(wallet: wallet)
//    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
//
//    let transferMessageBuilder = TransferMessageBuilder(
//      transferData: .stake(
//        .deposit(
//          TransferData.StakeDeposit(
//            seqno: seqno,
//            pool: stakingPool,
//            amount: updateAmount(amount: amount),
//            isMax: isMax,
//            isBouncable: true,
//            timeout: timeout
//          )
//        )
//      )
//    )
//    return transferMessageBuilder
  }
  
  private func updateFee(transactionInfo: MessageConsequences) {
    fatalError()
//    let fee = BigUInt(abs(transactionInfo.event.extra))
//    let extraFee = fee + stakingPool.implementation.extraFee
//    
//    var convertedFee: TransactionConfirmationModel.Amount?
//    let currency = currencyStore.getState()
//    if let rates = ratesStore.getState().first(where: { $0.currency == currency }) {
//      let rateConverter = RateConverter()
//      let converted = rateConverter.convert(
//        amount: extraFee,
//        amountFractionLength: TonInfo.fractionDigits,
//        rate: rates
//      )
//      convertedFee = TransactionConfirmationModel.Amount(
//        value: converted.amount,
//        decimals: converted.fractionLength,
//        currency: currency
//      )
//    }
//    
//    self.fee = .value(
//      TransactionConfirmationModel.Amount(
//        value: extraFee,
//        decimals: TonInfo.fractionDigits,
//        currency: .TON
//      ),
//      converted: convertedFee
//    )
  }
  
  private func getAmountValue() -> (amount: TransactionConfirmationModel.Amount, converted: TransactionConfirmationModel.Amount?) {
    let currency = currencyStore.state
    var convertedAmount: TransactionConfirmationModel.Amount?
    
    if let balance = balanceStore.state[wallet]?.walletBalance.balance.jettonsBalance.first(where: { $0.item.jettonInfo.address == jettonItem.jettonInfo.address }),
       let rate = balance.rates.first(where: { $0.value.currency == currency })?.value {
      let rateConverter = RateConverter()
      let converted = rateConverter.convert(
        amount: amount,
        amountFractionLength: jettonItem.jettonInfo.fractionDigits,
        rate: rate
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
        decimals: jettonItem.jettonInfo.fractionDigits,
        item: .symbol(jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name)
      ),
      convertedAmount
    )
  }
//  
//  private func updateAmount(amount: BigUInt) -> BigUInt {
//    return amount + stakingPool.implementation.depositExtraFee
//  }
  
  func signTransfer(_ transferBuilder: TransferMessageBuilder) async throws -> String {
    guard let signHandler,
          let signedData = try await signHandler(transferBuilder, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
