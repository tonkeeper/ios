import Foundation
import TonSwift
import BigInt
import TonAPI

final class StakingWithdrawTransactionConfirmationController: TransactionConfirmationController {
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
      feeState = .none
      return .failure(.failedToCalculateFee)
    }
  }
  
  func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
    do {
      let signedTransactions = try await createSignedBoc()
      
      if (signedTransactions.isEmpty) {
        return .failure(.failedToSendTransaction)
      }
      
      if (signedTransactions.count == 1) {
        try await sendService.sendTransaction(boc: signedTransactions[0], wallet: wallet)
      } else {
        try await sendService.sendTransactions(batch: signedTransactions, wallet: wallet)
      }
      return .success(())
    } catch TransactionConfirmationError.failedToSign {
      return .failure(.failedToSign)
    } catch {
      return .failure(.failedToSendTransaction)
    }
  }
  
  public var signHandler: ((TransferData, Wallet) async throws -> SignedTransactions?)?

  @Atomic private var feeState: TransactionConfirmationModel.FeeState = .loading
  
  private let wallet: Wallet
  private let stakingPool: StackingPoolInfo
  private let amount: BigUInt
  private let isCollect: Bool
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let balanceStore: BalanceStore
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  
  init(wallet: Wallet,
       stakingPool: StackingPoolInfo,
       amount: BigUInt,
       isCollect: Bool,
       sendService: SendService,
       blockchainService: BlockchainService,
       balanceStore: BalanceStore,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore) {
    self.wallet = wallet
    self.stakingPool = stakingPool
    self.amount = amount
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
          flow: .withdraw(isCollect: isCollect)
        )
      ),
      amount: getAmountValue(),
      feeState: feeState
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
  
  private func createSignedBoc() async throws -> SignedTransactions {
    let transferData = try await createTransferData()
    return try await signTransfer(transferData)
  }
  
  private func createTransferData() async throws -> TransferData {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    
    return TransferData(
      transfer: .stake(
        .withdraw(
          TransferData.StakeWithdraw(
            pool: stakingPool,
            amount: convertAmount(amount: amount),
            isBouncable: true,
            jettonWalletAddress: { [blockchainService] wallet, jettonMasterAddress in
              try await blockchainService.getWalletAddress(
                jettonMaster: jettonMasterAddress?.toRaw() ?? "",
                owner: wallet.address.toRaw(),
                isTestnet: wallet.isTestnet
              )
            }
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
    
    self.feeState = .fee(
      TransactionConfirmationModel.Fee(
        amount: TransactionConfirmationModel.Amount(
          token: .ton,
          value: extraFee
        ),
        type: .default
      )
    )
  }
  
  private func getAmountValue() -> TransactionConfirmationModel.Amount {
    return (
      TransactionConfirmationModel.Amount(
        token: .ton,
        value: amount
      )
    )
  }
  
  private func convertAmount(amount: BigUInt) -> BigUInt {
    guard stakingPool.implementation.type == .liquidTF else {
      return amount
    }
    
    guard let jettonMasterAddress = stakingPool.liquidJettonMaster else {
      return amount
    }
    
    guard let balance = balanceStore.getState()[wallet]?.walletBalance.balance,
    let jettonBalance = balance.jettonsBalance
      .first(where: { $0.item.jettonInfo.address == jettonMasterAddress }),
          let rate = jettonBalance.rates.first(where: { $0.key == .TON })?.value else {
      return 0
    }
    
    let rateConverter = RateConverter()
    let converted = rateConverter.convertFromCurrency(
      amount: amount,
      amountFractionLength: TonInfo.fractionDigits,
      rate: rate
    )
    
    return converted
  }
  
  func signTransfer(_ transferData: TransferData) async throws -> SignedTransactions {
    guard let signHandler,
          let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
    return signedData
  }
}
