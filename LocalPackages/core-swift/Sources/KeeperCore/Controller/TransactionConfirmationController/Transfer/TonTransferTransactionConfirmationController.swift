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
      let result = try await transferService.emulate(
        wallet: wallet,
        transfer: .ton(amount: amount, recipient: recipient, comment: comment)
      )
      self.emulationResult = result
      updateFee(emulationResult: emulationResult)
      return .success(())
    } catch {
      self.emulationResult = nil
      updateFee(emulationResult: nil)
      return .failure(.failedToCalculateFee)
    }
  }
  
  func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
    do {
      try await transferService.sendTransaction(
        wallet: wallet,
        transfer: .ton(amount: amount, recipient: recipient, comment: comment),
        transferType: emulationResult?.transferType ?? .default,
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
  
  public var signHandler: ((TransferData, Wallet) async throws -> SignedTransactions?)?
  
  @Atomic private var emulationResult: TransferEmulationResult?
  @Atomic private var fee: TransactionConfirmationModel.Fee = .loading
  
  private let wallet: Wallet
  private let recipient: Recipient
  private let amount: BigUInt
  private let comment: String?
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let transferService: TransferService
  
  init(wallet: Wallet,
       recipient: Recipient,
       amount: BigUInt,
       comment: String?,
       sendService: SendService,
       blockchainService: BlockchainService,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       transferService: TransferService) {
    self.wallet = wallet
    self.recipient = recipient
    self.amount = amount
    self.comment = comment
    self.sendService = sendService
    self.blockchainService = blockchainService
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.transferService = transferService
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
  
  private func updateFee(emulationResult: TransferEmulationResult?) {
    guard let emulationResult else {
      fee = .value(nil, converted: nil, isBattery: false)
      return
    }
    let fee = BigUInt(UInt64(abs(emulationResult.transactionInfo.event.extra)))
    
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
  
  func signTransfer(_ transferData: TransferData) async throws -> SignedTransactions {
    guard let signHandler,
          let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
