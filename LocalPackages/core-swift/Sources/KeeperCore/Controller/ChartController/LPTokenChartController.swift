import Foundation
import BigInt

public final class LPTokenChartController {
  public struct ProfitByMonth {
    public let month: TimeInterval
    public let amount: BigUInt
  }
  
  public var didUpdateProfits: (([ProfitByMonth]) -> Void)?
  public var didUpdateErrorState: (() -> Void)?
  public var diUpdateCurrentBalance: ((BigUInt) -> Void)?
  
  public let token: Token
  
  private let stakingPool: StakingPool
  private let jetton: JettonInfo
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let bigIntFormatter: BigIntAmountFormatter
  
  init(
    token: Token,
    stakingPool: StakingPool,
    jetton: JettonInfo,
    walletsStore: WalletsStore,
    walletBalanceStore: WalletBalanceStore,
    decimalAmountFormatter: DecimalAmountFormatter,
    bigIntFormatter: BigIntAmountFormatter
  ) {
    self.token = token
    self.stakingPool = stakingPool
    self.jetton = jetton
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.decimalAmountFormatter = decimalAmountFormatter
    self.bigIntFormatter = bigIntFormatter
  }
  
  public func start() async {
    await startObservations()
    await updateInitialChartData()
  }
  
  public func selectChartPoint(index: Int) {
    Task {
      await updateSelectedBalance(index: index)
    }
  }
  
  public func mapProfitsByMonth(_ profits: [ProfitByMonth]) -> [Coordinate] {
    profits.map {
      .init(
        x: $0.month,
        y: convertToDecimal(amount: $0.amount, fractionDigits: token.fractionDigits).doubleValue
      )
    }
  }
}

// MARK: - Private methods

private extension LPTokenChartController {
  func updateInitialChartData() async {
    do {
      let balance = try await loadBalance()
      await updateChartData(balance: balance)
    } catch {
      await MainActor.run {
        didUpdateErrorState?()
      }
    }
  }
  
  func startObservations() async {
    _ = await walletBalanceStore.addEventObserver(self) { [walletsStore] observer, event in
      switch event {
      case .balanceUpdate(let balance, let wallet):
        Task {
          guard walletsStore.activeWallet == wallet else { return }
          await observer.updateChartData(balance: balance.walletBalance.balance)
        }
      }
    }
  }
  
  func updateChartData(balance: Balance) async {
    let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jetton })?.quantity ?? .zero
    
    let currentDate = Date()
    let apyPercents = stakingPool.apy
    
    let profits: [ProfitByMonth] = monthlyProfitValues(apyPercents, investing: jettonBalance).enumerated()
      .map { index, value in
        let date = Calendar.current.date(byAdding: .month, value: index, to: currentDate) ?? Date()
        let timeInterval = date.timeIntervalSince1970
        return .init(month: timeInterval, amount: value)
      }
    
    await MainActor.run {
      didUpdateProfits?(profits)
      if let balance = profits.first {
        diUpdateCurrentBalance?(balance.amount)
      }
    }
  }
  
  func updateSelectedBalance(index: Int) async {
    do {
      let balance = try await loadBalance()
      let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jetton })?.quantity ?? .zero
      
      let currentDate = Date()
      let apyPercents = stakingPool.apy
      
      let profits: [ProfitByMonth] = monthlyProfitValues(apyPercents, investing: jettonBalance).enumerated()
        .map { index, value in
          let date = Calendar.current.date(byAdding: .month, value: index, to: currentDate) ?? Date()
          let timeInterval = date.timeIntervalSince1970
          return .init(month: timeInterval, amount: value)
        }
      
      await MainActor.run {
        if let balance = profits[safe: index] {
          diUpdateCurrentBalance?(balance.amount)
        }
      }
    } catch {
      await MainActor.run {
        didUpdateErrorState?()
      }
    }
  }
  
  func loadBalance() async throws -> Balance {
      return try await walletBalanceStore.getBalanceState(wallet: walletsStore.activeWallet)
        .walletBalance
        .balance
  }
  
  func annualProfit(_ apy: Decimal, investing: BigUInt) -> BigUInt {
    let apyFractionLength = max(Int(-apy.exponent), 0)
    let apyPlain = NSDecimalNumber(decimal: apy).multiplying(byPowerOf10: Int16(apyFractionLength))
    let apyBigInt = BigUInt(stringLiteral: apyPlain.stringValue)
    
    let scalingFactor = BigUInt(100) * BigUInt(10).power(apyFractionLength)
    
    return investing * apyBigInt / scalingFactor
  }
  
  func monthlyProfitValues(_ apy: Decimal, investing: BigUInt) -> [BigUInt] {
    var monthlyValues = [BigUInt]()
    monthlyValues.append(investing)
    
    let annualProfit = annualProfit(apy, investing: investing)
    let monthlyProfit = annualProfit / 12
    
    var currentInvesting = investing
    for _ in 1...12 {
      currentInvesting += monthlyProfit
      monthlyValues.append(currentInvesting)
    }
    
    return monthlyValues
  }
  
  func convertToDecimal(amount: BigUInt, fractionDigits: Int) -> Decimal {
    let formattedString = bigIntFormatter.format(amount: amount, fractionDigits: fractionDigits, maximumFractionDigits: fractionDigits)
    return Decimal(string: formattedString) ?? Decimal()
  }
}

extension Decimal {
    var doubleValue:Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }
}

private extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

