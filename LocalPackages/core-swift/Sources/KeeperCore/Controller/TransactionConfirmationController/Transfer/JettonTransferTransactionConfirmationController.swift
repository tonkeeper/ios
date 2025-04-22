import Foundation
import TKUIKit
import TonSwift
import BigInt
import TonAPI

final class JettonTransferTransactionConfirmationController: TransactionConfirmationController {
  
  private var preferredExtraType: TransactionConfirmationModel.ExtraType? = nil
  private var availableTypes: [TransactionConfirmationModel.ExtraType] = []
  
  func getModel() -> TransactionConfirmationModel {
    createModel()
  }
  
  func setLoading() {
    extraState = .loading
  }
  
  func emulate() async -> Result<Void, TransactionConfirmationError> {
    var availableTypes: [TransactionConfirmationModel.ExtraType] = [.default]

    do {
      defer {
        self.availableTypes = availableTypes
      }
      
      let transfer: Transfer = .jetton(jettonItem, transferAmount: BigUInt(1000000000), amount: isMax ? 1 : amount, recipient: recipient, comment: comment)
      
      let gaslessAvailable = await transferService.isGaslessAvailable(wallet: wallet, transfer: transfer)
      
      let isBatteryAvailable = await transferService.isRelayerAvailable(wallet: wallet, transfer: transfer)
      
      if isBatteryAvailable {
        availableTypes.append(.battery)
      }
      
      if gaslessAvailable {
        availableTypes.append(.gasless(token: jettonItem.jettonInfo))
      }
      
      let isMax = await {
        do {
          let balance = try await balanceService.loadWalletBalance(wallet: wallet, currency: .USD)
          let jettonBalance = balance.balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })
          return jettonBalance?.quantity == amount
        } catch {
          return false
        }
      }()
      self.isMax = isMax
      
      // By default we should offer battery transfer if available
      let preferredType: TransactionConfirmationModel.ExtraType = preferredExtraType ??
        (isBatteryAvailable ? .battery : .default)

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
        let minimumTransferAmount = BigUInt(stringLiteral: "50000000")
        guard let emulationResult else {
          return BigUInt(100000000)
        }
        if case .gasless = emulationResult.transferType {
          return minimumTransferAmount
        }
        
        var transferAmount = {
          switch emulationResult.extra.amount {
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
        transfer: .jetton(jettonItem, transferAmount: transferAmount, amount: getAmountValue().value, recipient: recipient, comment: comment),
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
  
  func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {
    self.preferredExtraType = extraType
  }
  
  public var signHandler: ((TransferData, Wallet) async throws -> SignedTransactions?)?
  
  @Atomic private var emulationResult: TransferEmulationResult?
  // TODO: сбрасывать стейт на время эмуляции
  @Atomic private var extraState: TransactionConfirmationModel.ExtraState = .loading
  @Atomic private var isMax: Bool = false

  private let wallet: Wallet
  private let recipient: Recipient
  private let jettonItem: JettonItem
  private let amount: BigUInt
  private let comment: String?
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let transferService: TransferService
  private let ratesService: RatesService
  private let balanceService: BalanceService
  
  init(wallet: Wallet,
       recipient: Recipient,
       jettonItem: JettonItem,
       amount: BigUInt,
       comment: String?,
       sendService: SendService,
       blockchainService: BlockchainService,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       transferService: TransferService,
       ratesService: RatesService,
       balanceService: BalanceService) {
    self.wallet = wallet
    self.recipient = recipient
    self.jettonItem = jettonItem
    self.amount = amount
    self.comment = comment
    self.sendService = sendService
    self.blockchainService = blockchainService
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.transferService = transferService
    self.ratesService = ratesService
    self.balanceService = balanceService
  }
  
  private func createModel() -> TransactionConfirmationModel {
    return TransactionConfirmationModel(
      wallet: wallet,
      recipient: recipient.recipientAddress.name,
      recipientAddress: recipient.recipientAddress.addressString,
      transaction: .transfer(.jetton(jettonItem.jettonInfo)),
      amount: getAmountValue(),
      extraState: extraState,
      comment: comment,
      availableExtraTypes: self.availableTypes
    )
  }
  
  private func updateFee(emulationResult: TransferEmulationResult?) async {
    guard let emulationResult else {
      extraState = .none
      return
    }
    let extra = emulationResult.extra
    
    let extraType: TransactionConfirmationModel.ExtraType
    switch emulationResult.transferType {
    case .battery:
      extraType = .battery
    case .gasless(_, _):
      extraType = .gasless(
        token: jettonItem.jettonInfo
      )
    case .default:
      extraType = .default
    }
    
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
    
    self.extraState = TransactionConfirmationModel.ExtraState.extra(
      isRefund ?
        .Refund(amount: confirmationModelAmount, type: extraType) :
        .Fee(
          amount: confirmationModelAmount,
          type: extraType
        )
    )
  }
  
  private func getAmountValue() -> TransactionConfirmationModel.Amount {
    let amount: () -> BigUInt = {
      if self.isMax {
        switch self.extraState {
        case .none, .loading:
          return self.amount
        case .extra(let extra):
          let (amount, type) = {
            switch extra {
            case .Fee(let amount, let type), .Refund(let amount, let type):
              return (amount, type)
            }
          }()
          
          switch type {
          case .battery, .default:
            return self.amount
          case .gasless(_):
            switch amount.token {
            case .ton:
              return self.amount
            case .jetton:
              return self.amount - amount.value
            }
          }
        }
      } else {
        return self.amount
      }
    }
    
    return (
      TransactionConfirmationModel.Amount(
        token: .jetton(jettonItem),
        value: amount()
      )
    )
  }
  
  func signTransfer(_ transferData: TransferData) async throws -> SignedTransactions {
    guard let signHandler,
          let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
