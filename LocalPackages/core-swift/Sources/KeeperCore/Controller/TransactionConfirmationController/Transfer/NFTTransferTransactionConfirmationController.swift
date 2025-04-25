import Foundation
import TonSwift
import BigInt
import TonAPI

final class NFTTransferTransactionConfirmationController: TransactionConfirmationController {
  func getModel() -> TransactionConfirmationModel {
    createModel()
  }
  
  func setLoading() {
    extraState = .loading
  }
  
  private var preferredExtraType: TransactionConfirmationModel.ExtraType? = nil
  private var availableTypes: [TransactionConfirmationModel.ExtraType] = []
  
  func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {
    preferredExtraType = extraType
    var transferSettings = settingsRepository.getTransferSettings(wallet: wallet)
    switch extraType {
    case .default:
      transferSettings.jettonTransfer = .default
    case .battery:
      transferSettings.jettonTransfer = .battery
    case .gasless:
      return
    }
    try? settingsRepository.setTransferSettings(wallet: wallet, transferSettings: transferSettings)
  }
  
  func emulate() async -> Result<Void, TransactionConfirmationError> {
    var availableTypes: [TransactionConfirmationModel.ExtraType] = [.default]

    do {
      defer {
        self.availableTypes = availableTypes
      }
      
      let transfer: Transfer = .nft(nft, transferAmount: BigUInt(1000000000), recipient: recipient, comment: comment)
      
      let isBatteryAvailable = await transferService.isRelayerAvailable(wallet: wallet, transfer: transfer)
      
      if isBatteryAvailable {
        availableTypes.append(.battery)
      }
      
      let preferredType: TransactionConfirmationModel.ExtraType = {
        if let preferredExtraType { return preferredExtraType }
        switch settingsRepository.getTransferSettings(wallet: wallet).jettonTransfer {
        case .default:
          return .default
        case .gasless:
          return isBatteryAvailable ? .battery : .default
        case .battery:
          return isBatteryAvailable ? .battery : .default
        }
      }()
      
      let result = try await transferService.emulate(
        wallet: wallet,
        transfer: transfer,
        params: [.init(address: try wallet.address.toRaw(), balance: Int64(2000000000))],
        preferredExtraType: preferredType
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
        let emulationExtra = emulationResult.extra.amount
        let minimumTransferAmount = BigUInt(stringLiteral: "50000000")
        
        var transferAmount = {
          switch emulationExtra {
          case .Fee(let fee):
            return fee + minimumTransferAmount
          case .Refund(_):
            return minimumTransferAmount
          }
        }()

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
  @Atomic private var extraState: TransactionConfirmationModel.ExtraState = .loading
  
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
  private let settingsRepository: SettingsRepository
  
  init(wallet: Wallet,
       recipient: Recipient,
       nft: NFT,
       comment: String?,
       sendService: SendService,
       blockchainService: BlockchainService,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       transferService: TransferService,
       ratesService: RatesService,
       settingsRepository: SettingsRepository) {
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
    self.settingsRepository = settingsRepository
  }
  
  private func createModel() -> TransactionConfirmationModel {
    return TransactionConfirmationModel(
      wallet: wallet,
      recipient: recipient.recipientAddress.name,
      recipientAddress: recipient.recipientAddress.addressString,
      transaction: .transfer(.nft(nft)),
      amount: nil,
      extraState: extraState,
      comment: comment,
      availableExtraTypes: [.default, .battery]
    )
  }
  
  private func updateFee(emulationResult: TransferEmulationResult?) async {
    guard let emulationResult else {
      extraState = .none
      return
    }
    let extra = emulationResult.extra
    
    let extraType: TransactionConfirmationModel.ExtraType
    extraType = emulationResult.transferType.isBattery ? .battery : .default
    
    let (amount, isRefund) = {
      switch extra.amount {
      case .Fee(let fee):
        return (fee, false)
      case .Refund(let refund):
        return (refund, true)
      }
    }()
    
    let confirmationModelAmount = TransactionConfirmationModel.Amount(
      token: extra.token,
      value: amount
    )
    
    self.extraState = .extra(
      isRefund ? .Refund(
        amount: confirmationModelAmount,
        type: extraType
      ) : .Refund(
        amount: confirmationModelAmount,
        type: extraType
      )
    )
  }
  
  func signTransfer(_ transferData: TransferData) async throws -> SignedTransactions {
    guard let signHandler,
          let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
