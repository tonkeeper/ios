import Foundation
import TonSwift
import BigInt

public final class StakingDepositConfirmationController: StakingConfirmationController {
  
  public var didUpdateModel: ((StakingConfirmationModel) -> Void)?
  public var didGetError: ((StakingConfirmationError) -> Void)?
  public var didGetExternalSign: ((URL) async throws -> Data?)?
  
  private let stakingPool: StakingPool
  
  private let amount: BigUInt
  private var estimatedFee: Int64?
  private let isMaxAmount: Bool
  
  private let balanceStore: BalanceStore
  private let ratesStore: RatesStore
  private let walletsStore: WalletsStore
  private let currencyStore: CurrencyStore
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  private let sendService: SendService
  private let signService: TransferSignService
  
  init(
    stakingPool: StakingPool,
    amount: BigUInt,
    isMax: Bool,
    walletsStore: WalletsStore,
    balanceStore: BalanceStore,
    ratesStore: RatesStore,
    currencyStore: CurrencyStore,
    signService: TransferSignService,
    amountFormatter: AmountFormatter,
    decimalFormatter: DecimalAmountFormatter,
    sendService: SendService
  ) {
    self.stakingPool = stakingPool
    self.amount = amount
    self.isMaxAmount = isMax
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.signService = signService
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
    self.sendService = sendService
  }
  
  public func start() async {
    let model = await makeModel(fee: .loading, feeConverted: .value(nil))
    await MainActor.run {
      didUpdateModel?(model)
    }
    await emulate()
  }
  
  public func sendTransaction() async throws {
    signService.didGetExternalSign = didGetExternalSign
    do {
      let transactionBoc = try await createTransactionBoc {
        try await signService.getSign($0, wallet: walletsStore.activeWallet)
      }
      
      try await sendService.sendTransaction(boc: transactionBoc, wallet: walletsStore.activeWallet)
      NotificationCenter.default.post(
        name: NSNotification.Name(rawValue: "DID SEND TRANSACTION"),
        object: nil,
        userInfo: ["Wallet": walletsStore.activeWallet]
      )
    } catch {
      Task { @MainActor in
        didGetError?(.failedToSendTransaction)
      }
      throw error
    }
  }
  
  public func isNeedToConfirm() -> Bool {
    return walletsStore.activeWallet.isRegular
  }
  
  public func checkTransactionSendingStatus() -> StakingTransactionSendingStatus {
    let wallet = walletsStore.activeWallet
    
    guard let estimatedFee else {
      return .feeIsNotSet
    }
    
    let balance = (try? balanceStore.getBalance(wallet: wallet).balance.tonBalance.amount) ?? .zero
    let refundedAmount = stakingPool.implementation.withdrawalFee
    let balanceAmount = BigUInt(integerLiteral: UInt64(balance))
    let totalDepositExpenses = getTotalDepositExpenses()
    var estimatedFeeBigInt = BigUInt(estimatedFee)
    if isMaxAmount {
      estimatedFeeBigInt = .zero
    }
    
    guard balanceAmount >= (totalDepositExpenses + estimatedFeeBigInt) else {
      let model = StakingTransactionSendingStatus.InsufficientFunds(
        estimatedFee: BigUInt(estimatedFee),
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

private extension StakingDepositConfirmationController {
  func emulate() async {
    async let createTransactionBocTask = createTransactionBoc {
      try $0.signMessage(signer: WalletTransferEmptyKeySigner())
    }
    
    do {
      let transactionBoc = try await createTransactionBocTask
      let transactionInfo = try await sendService.loadTransactionInfo(
        boc: transactionBoc,
        wallet: walletsStore.activeWallet
      )
      
      estimatedFee = transactionInfo.trace.transaction.total_fees
      let model = await makeEmulatedModel(fee: estimatedFee)
      
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
  
  func makeEmulatedModel(fee: Int64?) async -> StakingConfirmationModel {
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
      let rates = ratesStore.getRates(jettons: [])
      let currency = await currencyStore.getActiveCurrency()
      if let rates = rates.ton.first(where: { $0.currency == currency }) {
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
  
  func createTransactionBoc(
    signClosure: (WalletTransfer) async throws -> Data
  ) async throws -> String {
    let seqno = try await sendService.loadSeqno(wallet: walletsStore.activeWallet)
    let timeout = await sendService.getTimeoutSafely(wallet: walletsStore.activeWallet)
    let amount = getTotalDepositExpenses()
  
    return try await StakingMessageBuilder.deposit(
      wallet: walletsStore.activeWallet,
      seqno: seqno,
      poolAddress: stakingPool.address,
      poolImplementation: stakingPool.implementation,
      amount: amount,
      timeout: timeout,
      isMax: isMaxAmount,
      signClosure: signClosure
    )
  }
  
  func makeModel(
    fee: LoadableModelItem<String>,
    feeConverted: LoadableModelItem<String?>
  ) async -> StakingConfirmationModel {
    let pool = stakingPool
    
    let poolName = pool.name
    let poolImage: StakingPoolImage = .fromResource
    let apyFormatted = makeFromattedAPY(pool)
    var formattedConvertedAmount: String?
    
    let formattedAmount = amountFormatter.formatAmount(
      amount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits
    )
    
    let rates = ratesStore.getRates(jettons: []).ton
    let currency = await currencyStore.getActiveCurrency()
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
    
    return  .init(
      poolName: poolName,
      poolImage: poolImage,
      wallet: walletsStore.activeWallet.model.emojiLabel,
      apyPercent: apyFormatted,
      operationName: .depositOperation,
      amount: formattedAmount,
      amountConverted: formattedConvertedAmount,
      fee: fee,
      feeConverted: feeConverted,
      kind: pool.implementation.type,
      tokenSymbol: TonInfo.symbol
    )
  }
  
  func getTotalDepositExpenses() -> BigUInt {
    let pool = stakingPool
    switch pool.implementation.type {
    case .liquidTF:
      return isMaxAmount ? amount : amount + pool.implementation.withdrawalFee
    case .whales:
      return amount
    case .tf:
      return amount
    }
  }
  
  func makeFromattedAPY(_ pool: StakingPool) -> String {
    let apyPercents = decimalFormatter.format(amount: pool.apy, maximumFractionDigits: 2)
    return "≈ \(apyPercents)%"
  }
}

private extension String {
  static let depositOperation = "Deposit"
}
