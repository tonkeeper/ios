import Foundation
import TonSwift
import BigInt

public final class StakeDepositConfirmationController: StakeConfirmationController {
  
  public enum Error: Swift.Error {
    case failedToCalculateFee
    case failedToSendTransaction
    case failedToSign
  }
  
  public var didUpdateModel: ((StakeConfirmationModel) -> Void)?
  public var didGetError: ((StakeConfirmationError) -> Void)?
  public var didGetExternalSign: ((URL) async throws -> Data?)?
  
  public var signHandler: ((TransferMessageBuilder, Wallet) async throws -> String?)?
  
  private var transactionEmulationExtra: Int64?
  
  public let wallet: Wallet
  private let stakingPool: StackingPoolInfo
  private let amount: BigUInt
  private let isMax: Bool
  private let sendService: SendService
  private let accountService: AccountService
  private let blockchainService: BlockchainService
  private let balanceStore: BalanceStore
  private let ratesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  
  init(wallet: Wallet,
       stakingPool: StackingPoolInfo,
       amount: BigUInt,
       isMax: Bool,
       sendService: SendService,
       accountService: AccountService,
       blockchainService: BlockchainService,
       balanceStore: BalanceStore,
       ratesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       amountFormatter: AmountFormatter,
       decimalFormatter: DecimalAmountFormatter) {
    self.wallet = wallet
    self.stakingPool = stakingPool
    self.amount = amount
    self.isMax = isMax
    self.sendService = sendService
    self.accountService = accountService
    self.blockchainService = blockchainService
    self.balanceStore = balanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
  }
  
  public func start() async {
    let model = await makeModel(fee: .loading, feeConverted: .value(nil))
    await MainActor.run {
      didUpdateModel?(model)
    }
    await emulate()
  }
  
  public func sendTransaction() async throws {
    do {
      let transactionBoc = try await createTransactionBoc()
      try await sendService.sendTransaction(boc: transactionBoc, wallet: wallet)
      NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
    } catch {
      Task { @MainActor in
        didGetError?(.failedToSendTransaction)
      }
      throw error
    }
  }
  
  public func checkTransactionSendingStatus() async -> StakingTransactionSendingStatus {
    guard let transactionEmulationExtra else {
      return .feeIsNotSet
    }
    
    let balance = await balanceStore.getState()[wallet]?.walletBalance.balance.tonBalance.amount ?? .zero
    let refundedAmount = stakingPool.implementation.withdrawalFee
    let balanceAmount = BigUInt(integerLiteral: UInt64(balance))
    let totalDepositExpenses = getTotalDepositExpenses()
    var estimatedFeeBigInt = BigUInt(transactionEmulationExtra)
    if isMax {
      estimatedFeeBigInt = .zero
    }
    
    guard balanceAmount >= (totalDepositExpenses + estimatedFeeBigInt) else {
      let model = StakingTransactionSendingStatus.InsufficientFunds(
        estimatedFee: BigUInt(transactionEmulationExtra),
        refundedAmount: refundedAmount,
        token: .ton,
        wallet: wallet
      )
      return .insufficientFunds(model)
    }
    
    return .ready
  }
}

// MARK: - Private methods

private extension StakeDepositConfirmationController {
  func emulate() async {
    async let createTransactionBocTask = createEmulateTransactionBoc()
    
    do {
      let transactionBoc = try await createTransactionBocTask
      let transactionInfo = try await sendService.loadTransactionInfo(
        boc: transactionBoc,
        wallet: wallet
      )
      
      transactionEmulationExtra = transactionInfo.trace.transaction.totalFees
      let model = await makeEmulatedModel(fee: transactionEmulationExtra)
      
      Task { @MainActor in
        didUpdateModel?(model)
      }
    } catch {
      let model = await makeEmulatedModel(fee: nil)
      Task { @MainActor in
        didUpdateModel?(model)
        didGetError?(.failedToCalculateFee)
      }
    }
  }
  
  func makeEmulatedModel(fee: Int64?) async -> StakeConfirmationModel {
    let feeItem: LoadableModelItem<String>
    let feeConverted: LoadableModelItem<String?>
    if let fee = fee {
      let feeFormatted = amountFormatter.formatAmount(
        BigUInt(UInt64(fee)),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: TonInfo.fractionDigits,
        symbol: TonInfo.symbol
      )
      feeItem = .value(feeFormatted)
      let rates = await ratesStore.getState()
      let currency = await currencyStore.getState()
      if let rates = rates.first(where: { $0.currency == currency }) {
        let rateConverter = RateConverter()
        let converted = rateConverter.convert(
          amount: fee,
          amountFractionLength: TonInfo.fractionDigits,
          rate: rates
        )
        let convertedFeeFormatted = amountFormatter.formatAmount(
          converted.amount,
          fractionDigits: converted.fractionLength,
          maximumFractionDigits: 2,
          currency: currency
        )
        feeConverted = .value(convertedFeeFormatted)
      } else {
        feeConverted = .value(nil)
      }
    } else {
      feeItem = .value("")
      feeConverted = .value(nil)
    }
    
    return await makeModel(fee: feeItem, feeConverted: feeConverted)
  }
  
  func createEmulateTransactionBoc() async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let amount = getTotalDepositExpenses()
    
    let transferMessageBuilder = TransferMessageBuilder(
      transferData: .stake(
        .deposit(
          TransferData.StakeDeposit(
            seqno: seqno,
            pool: stakingPool,
            amount: amount,
            isBouncable: true,
            timeout: timeout
          )
        )
      )
    )
    return try await transferMessageBuilder.createBoc { transfer in
      try await transferMessageBuilder.externalSign(wallet: wallet) { transfer in
        try transfer.signMessage(signer: WalletTransferEmptyKeySigner())
      }
    }
  }
  
  func createTransactionBoc() async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let amount = getTotalDepositExpenses()
    
    let transferMessageBuilder = TransferMessageBuilder(
      transferData: .stake(
        .deposit(
          TransferData.StakeDeposit(
            seqno: seqno,
            pool: stakingPool,
            amount: amount,
            isBouncable: true,
            timeout: timeout
          )
        )
      )
    )
    return try await transferMessageBuilder.createBoc { transfer in
      return try await signTransfer(transfer)
    }
  }
  
  func makeModel(
    fee: LoadableModelItem<String>,
    feeConverted: LoadableModelItem<String?>
  ) async -> StakeConfirmationModel {
    let pool = stakingPool
    
    let poolName = pool.name
    let apyFormatted = makeFromattedAPY(pool)
    var formattedConvertedAmount: String?
    
    let formattedAmount = amountFormatter.formatAmount(
      amount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits
    )
    
    let rates = await ratesStore.getState()
    let currency = await currencyStore.getState()
    if let rates = rates.first(where: { $0.currency == currency }) {
      let rateConverter = RateConverter()
      let converted = rateConverter.convert(
        amount: amount,
        amountFractionLength: TonInfo.fractionDigits,
        rate: rates
      )
      
      formattedConvertedAmount = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
    }
    
    return StakeConfirmationModel(
      poolName: poolName,
      poolImplementation: pool.implementation,
      wallet: wallet,
      apyPercent: apyFormatted,
      operationName: .depositOperation,
      amount: formattedAmount,
      amountConverted: formattedConvertedAmount,
      fee: fee,
      feeConverted: feeConverted,
      tokenSymbol: TonInfo.symbol,
      buttonTitle: "Confirm and Stake"
    )
  }
  
  func getTotalDepositExpenses() -> BigUInt {
    let pool = stakingPool
    switch pool.implementation.type {
    case .liquidTF:
      return isMax ? amount : amount + pool.implementation.withdrawalFee
    case .whales:
      return amount
    case .tf:
      return amount
    }
  }
  
  func makeFromattedAPY(_ pool: StackingPoolInfo) -> String {
    let apyPercents = decimalFormatter.format(amount: pool.apy, maximumFractionDigits: 2)
    return "≈ \(apyPercents)%"
  }
  
  func signTransfer(_ transferBuilder: TransferMessageBuilder) async throws -> String {
    guard let signHandler,
          let signedData = try await signHandler(transferBuilder, wallet) else { throw Error.failedToSign }
    return signedData
  }
}

private extension String {
  static let depositOperation = "Deposit"
}
