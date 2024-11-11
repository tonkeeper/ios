import Foundation
import TonSwift
import BigInt
import TonAPI

final class TonTransferTransactionConfirmationController: TransactionConfirmationController {
  func getModel() -> TransactionConfirmationModel {
    createModel()
  }
  
  func emulate() async -> Result<Void, TransactionConfirmationError> {
    do {
      let payload = try await transferTransaction.calculateFee(
        wallet: wallet,
        transfer: .ton(amount: amount),
        recipient: recipient,
        comment: comment
      )
      self.transferPayload = payload
      updateFee(payload: transferPayload)
      return .success(())
    } catch {
      self.transferPayload = nil
      updateFee(payload: nil)
      return .failure(.failedToCalculateFee)
    }
  }
  
  func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
    do {
      try await transferTransaction.sendTransaction(
        wallet: wallet,
        transfer: .ton(amount: amount),
        recipient: recipient,
        comment: comment,
        transferType: transferPayload?.type ?? .default,
        signClosure: { [weak self, wallet] transferData in
          guard let signed = try? await self?.signHandler?(transferData, wallet) else {
            throw TransactionConfirmationError.failedToSign
          }
          return signed
        }
      )
      return .success(())
    } catch {
      return .failure(.failedToSendTransaction)
    }
  }
  
  public var signHandler: ((TransferData, Wallet) async throws -> String?)?
  
  @Atomic private var transferPayload: TransferTransaction.TransferPayload?
  @Atomic private var fee: TransactionConfirmationModel.Fee = .loading
  
  private let wallet: Wallet
  private let recipient: Recipient
  private let amount: BigUInt
  private let comment: String?
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let transferTransaction: TransferTransaction
  
  init(wallet: Wallet,
       recipient: Recipient,
       amount: BigUInt,
       comment: String?,
       sendService: SendService,
       blockchainService: BlockchainService,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       transferTransaction: TransferTransaction) {
    self.wallet = wallet
    self.recipient = recipient
    self.amount = amount
    self.comment = comment
    self.sendService = sendService
    self.blockchainService = blockchainService
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.transferTransaction = transferTransaction
  }
  
  private func createModel() -> TransactionConfirmationModel {
    return TransactionConfirmationModel(
      wallet: wallet,
      recipient: recipient.recipientAddress.name,
      recipientAddress: recipient.recipientAddress.addressString,
      transaction: .transfer(.ton),
      amount: getAmountValue(),
      fee: fee,
      comment: comment
    )
  }
  
  private func updateFee(payload: TransferTransaction.TransferPayload?) {
    guard let payload else {
      fee = .value(nil, converted: nil, isBattery: false)
      return
    }
    let fee = BigUInt(payload.fee)
    
    var convertedFee: TransactionConfirmationModel.Amount?
    let currency = currencyStore.getState()
    if let rates = ratesStore.getState().first(where: { $0.currency == currency }) {
      let rateConverter = RateConverter()
      let converted = rateConverter.convert(
        amount: fee,
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
        value: fee,
        decimals: TonInfo.fractionDigits,
        item: .currency(.TON)
      ),
      converted: convertedFee
    )
  }
  
  private func getAmountValue() -> (amount: TransactionConfirmationModel.Amount, converted: TransactionConfirmationModel.Amount?) {
    let currency = currencyStore.state
    var convertedAmount: TransactionConfirmationModel.Amount?
    
    if let rate = ratesStore.state.first(where: { $0.currency == currency }) {
      let rateConverter = RateConverter()
      let converted = rateConverter.convert(
        amount: amount,
        amountFractionLength: TonInfo.fractionDigits,
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
        decimals: TonInfo.fractionDigits,
        item: .currency(.TON)
      ),
      convertedAmount
    )
  }
  
  func signTransfer(_ transferData: TransferData) async throws -> String {
    guard let signHandler,
          let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
