import Foundation
import TonSwift
import BigInt
import TonAPI

final class NFTTransferTransactionConfirmationController: TransactionConfirmationController {
  func getModel() -> TransactionConfirmationModel {
    createModel()
  }
  
  func emulate() async -> Result<Void, TransactionConfirmationError> {
    do {
      
      let result = try await transferService.emulate(
        wallet: wallet,
        transfer: .nft(nft, transferAmount: BigUInt(1000000000), recipient: recipient, comment: comment),
        params: [.init(address: try wallet.address.toRaw(), balance: Int64(2000000000))]
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
        transfer: .nft(nft, transferAmount: transferAmount, recipient: recipient, comment: comment),
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
  private let nft: NFT
  private let comment: String?
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let transferService: TransferService
  private let ratesService: RatesService
  
  init(wallet: Wallet,
       recipient: Recipient,
       nft: NFT,
       comment: String?,
       sendService: SendService,
       blockchainService: BlockchainService,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       transferService: TransferService,
       ratesService: RatesService) {
    self.wallet = wallet
    self.recipient = recipient
    self.nft = nft
    self.comment = comment
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
      transaction: .transfer(.nft(nft)),
      amount: nil,
      fee: fee,
      comment: comment
    )
  }
  
  private func updateFee(emulationResult: TransferEmulationResult?) async {
    guard let emulationResult else {
      fee = .value(nil, converted: nil, isBattery: false, gasless: nil)
      return
    }
    let fee = emulationResult.fee
    
    var convertedFee: TransactionConfirmationModel.Amount?
    let currency = currencyStore.getState()
    let rates: Rates.Rate? = await getFeeRate(fee: fee, currency: currency)
    if let rates = rates {
      let rateConverter = RateConverter()
      let converted = rateConverter.convert(
        amount: fee.amount,
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
        value: fee.amount,
        decimals: fee.token.fractionDigits,
        item: .symbol(fee.token.symbol)
      ),
      converted: convertedFee,
      isBattery: emulationResult.transferType.isBattery,
      gasless: nil
    )
  }
  
  func signTransfer(_ transferData: TransferData) async throws -> SignedTransactions {
    guard let signHandler,
          let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
  
  func getFeeRate(fee: TransferEmulationResult.Fee, currency: Currency) async -> Rates.Rate? {
    do {
      let jettons: [JettonInfo] = {
        switch fee.token {
        case .ton:
          return []
        case .jetton(let jettonItem):
          return [jettonItem.jettonInfo]
        }
      }()
      let rates = try await ratesService.loadRates(jettons: jettons, currencies: [currency])
      switch fee.token {
      case .ton:
        return rates.ton
          .first(where: { $0.currency == currency })
      case .jetton(let jettonItem):
        return rates.jettonsRates
          .first(where: { $0.jettonInfo.address == jettonItem.jettonInfo.address })?
          .rates
          .first(where: { $0.currency == currency })
      }
    } catch {
      return nil
    }
  }
}
