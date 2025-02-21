import Foundation
import TonSwift
import BigInt
import TonAPI

final class JettonTransferTransactionConfirmationController: TransactionConfirmationController {
  
  private var preferGasless: Bool = true
  
  func getModel() -> TransactionConfirmationModel {
    createModel()
  }
  
  func emulate() async -> Result<Void, TransactionConfirmationError> {
    do {
      let result = try await transferService.emulate(
        wallet: wallet,
        transfer: .jetton(jettonItem, transferAmount: BigUInt(1000000000), amount: amount, recipient: recipient, comment: comment),
        params: [.init(address: try wallet.address.toRaw(), balance: Int64(2000000000))],
        isPreferGasless: preferGasless
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
      let transferAmount: BigUInt = {
        guard let emulationResult else {
          return BigUInt(100000000)
        }
        let emulationExtra = emulationResult.fee.amount
        let minimumTransferAmount = BigUInt(stringLiteral: "50000000")
        var transferAmount = emulationExtra + minimumTransferAmount
        transferAmount = transferAmount < minimumTransferAmount
        ? minimumTransferAmount
        : transferAmount
        return transferAmount
      }()
      try await transferService.sendTransaction(
        wallet: wallet,
        transfer: .jetton(jettonItem, transferAmount: transferAmount, amount: amount, recipient: recipient, comment: comment),
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
  
  func toggleIsPreferGasless() {
    preferGasless.toggle()
  }
  
  public var signHandler: ((TransferData, Wallet) async throws -> SignedTransactions?)?
  
  @Atomic private var emulationResult: TransferEmulationResult?
  @Atomic private var feeState: TransactionConfirmationModel.FeeState = .loading
  
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
  private let transferService: TransferService
  private let ratesService: RatesService
  
  init(wallet: Wallet,
       recipient: Recipient,
       jettonItem: JettonItem,
       amount: BigUInt,
       comment: String?,
       sendService: SendService,
       blockchainService: BlockchainService,
       balanceStore: BalanceStore,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       transferService: TransferService,
       ratesService: RatesService) {
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
    self.transferService = transferService
    self.ratesService = ratesService
  }
  
  private func createModel() -> TransactionConfirmationModel {
    return TransactionConfirmationModel(
      wallet: wallet,
      recipient: recipient.recipientAddress.name,
      recipientAddress: recipient.recipientAddress.addressString,
      transaction: .transfer(.jetton(jettonItem.jettonInfo)),
      amount: getAmountValue(),
      feeState: feeState,
      comment: comment
    )
  }
  
  private func updateFee(emulationResult: TransferEmulationResult?) async {
    guard let emulationResult else {
      feeState = .none
      return
    }
    let fee = emulationResult.fee
    
    let feeType: TransactionConfirmationModel.FeeType
    switch emulationResult.transferType {
    case .battery:
      feeType = .battery
    case .gasless(_, _):
      switch emulationResult.fee.token {
      case .ton:
        feeType = .gasless(
          toggleOption: .jetton(jettonItem)
        )
      case .jetton:
        feeType = .gasless(
          toggleOption: .ton
        )
      }
    case .default:
      if emulationResult.isGaslessAvailable {
        feeType = .gasless(
          toggleOption: .jetton(jettonItem)
        )
      } else {
        feeType = .default
      }
    }
    
    self.feeState = TransactionConfirmationModel.FeeState.fee(
      TransactionConfirmationModel.Fee(
        amount: TransactionConfirmationModel.Amount(
          token: fee.token,
          value: fee.amount
        ),
        type: feeType
      )
    )
  }
  
  private func getAmountValue() -> TransactionConfirmationModel.Amount {
    return (
      TransactionConfirmationModel.Amount(
        token: .jetton(jettonItem),
        value: amount
      )
    )
  }
  
  func signTransfer(_ transferData: TransferData) async throws -> SignedTransactions {
    guard let signHandler,
          let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
