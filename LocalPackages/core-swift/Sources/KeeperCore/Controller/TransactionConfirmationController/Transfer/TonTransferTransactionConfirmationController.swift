import Foundation
import TonSwift
import BigInt
import TonAPI

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
  @Atomic private var extraState: TransactionConfirmationModel.ExtraState = .loading
  
  private let wallet: Wallet
  private let recipient: Recipient
  private let amount: BigUInt
  private let comment: String?
  private let isMaxAmount: Bool
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let transferService: TransferService
  private let ratesService: RatesService
  
  init(wallet: Wallet,
       recipient: Recipient,
       amount: BigUInt,
       comment: String?,
       isMaxAmount: Bool,
       sendService: SendService,
       blockchainService: BlockchainService,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       transferService: TransferService,
       ratesService: RatesService) {
    self.wallet = wallet
    self.recipient = recipient
    self.amount = amount
    self.comment = comment
    self.isMaxAmount = isMaxAmount
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
      recipientAddress: recipient.recipientAddress.addressString,
      transaction: .transfer(.ton(isMaxAmount)),
      amount: getAmountValue(),
      extraState: extraState,
      comment: comment,
      availableExtraTypes: [.default]
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
      case .Fee(let amount):
        return (amount, false)
      case .Refund(let amount):
        return (amount, true)
      }
    }()
    
    let confirmationModelAmount = TransactionConfirmationModel.Amount(
      token: extra.token,
      value: amount
    )
    
    self.extraState = .extra(
      isRefund ?
        .Refund(amount: confirmationModelAmount, type: .default) :
          .Fee(
            amount: confirmationModelAmount,
            type: .default
          )
    )
  }
  
  private func getAmountValue() -> TransactionConfirmationModel.Amount {
    return TransactionConfirmationModel.Amount(
      token: .ton,
      value: amount
    )
  }
  
  private func signTransfer(_ transferData: TransferData) async throws -> SignedTransactions {
    guard let signHandler,
          let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
