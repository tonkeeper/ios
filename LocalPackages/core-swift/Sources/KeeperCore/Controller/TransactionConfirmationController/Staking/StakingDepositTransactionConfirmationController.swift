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
  
  public var signHandler: ((TransferData, Wallet) async throws -> String?)?

  private var fee: TransactionConfirmationModel.Fee = .loading
  
  private let wallet: Wallet
  private let stakingPool: StackingPoolInfo
  private let amount: BigUInt
  private let isCollect: Bool
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let tonBalanceService: TonBalanceService
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  
  init(wallet: Wallet,
       stakingPool: StackingPoolInfo,
       amount: BigUInt,
       isCollect: Bool,
       sendService: SendService,
       blockchainService: BlockchainService,
       tonBalanceService: TonBalanceService,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore) {
    self.wallet = wallet
    self.stakingPool = stakingPool
    self.amount = amount
    self.isCollect = isCollect
    self.sendService = sendService
    self.blockchainService = blockchainService
    self.tonBalanceService = tonBalanceService
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
  
  private func createSignedBoc() async throws -> String {
    let transferData = try await createTransferData()
    return try await signTransfer(transferData)
  }
  
  private func createTransferData() async throws -> TransferData {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let isMax = await {
      do {
        let balance = try await tonBalanceService.loadBalance(wallet: wallet)
        return amount == BigUInt(integerLiteral: UInt64(balance.amount))
      } catch {
        return false
      }
    }()
    
    return TransferData(
      transfer: .stake(
        .deposit(
          TransferData.StakeDeposit(
            pool: stakingPool,
            amount: updateAmount(amount: amount),
            isMax: isMax,
            isBouncable: true
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
  
  func signTransfer(_ transferData: TransferData) async throws -> String {
    guard let signHandler,
          let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
