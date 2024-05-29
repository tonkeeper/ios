import Foundation
import BigInt

public final class BuySellOperatorController {
  
  public enum Remaining {
    case remaining(String)
    case insufficient
  }
  
  public var didUpdateConvertedValue: ((String) -> Void)?
  public var didUpdateInputValue: ((String?) -> Void)?
  public var didUpdateInputSymbol: ((String?) -> Void)?
  public var didUpdateMaximumFractionDigits: ((Int) -> Void)?
  public var didUpdateIsTokenPickerAvailable: ((Bool) -> Void)?
  public var didUpdateIsContinueEnabled: ((Bool) -> Void)?
  public var didUpdateRemaining: ((Remaining) -> Void)?
  public var didUpdateMethods: (([[BuySellItemModel]], [FiatMethodLayout]) -> Void)?
  
  private var isTokenAmountInput = true {
    didSet {
      didChangeInputMode()
    }
  }
  
  private var rate: Rates.Rate?
  
  private var isMax = false {
    didSet {
      didToggleMax()
    }
  }
  
  public private(set) var token: Token
  var currency: Currency = .USD
  var tokenAmount: BigUInt {
    didSet {
      didUpdateTokenAmount()
    }
  }
  public let wallet: Wallet
  private let buySellMethodsService: BuySellMethodsService
  private let balanceStore: BalanceStore
  private let ratesStore: RatesStore
  private let currencyStore: CurrencyStore
  private let rateConverter: RateConverter
  private let locationService: LocationService
  private let configurationStore: ConfigurationStore
  private let amountFormatter: AmountFormatter
  private let isMarketRegionPickerAvailable: () async -> Bool
  
  init(token: Token,
       tokenAmount: BigUInt,
       wallet: Wallet,
       balanceStore: BalanceStore,
       ratesStore: RatesStore,
       currencyStore: CurrencyStore,
       buySellMethodsService: BuySellMethodsService,
       locationService: LocationService,
       configurationStore: ConfigurationStore,
       rateConverter: RateConverter,
       amountFormatter: AmountFormatter,
       isMarketRegionPickerAvailable: @escaping () async -> Bool) {
    self.token = token
    self.tokenAmount = tokenAmount
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.buySellMethodsService = buySellMethodsService
    self.locationService = locationService
    self.configurationStore = configurationStore
    self.rateConverter = rateConverter
    self.amountFormatter = amountFormatter
    self.isMarketRegionPickerAvailable = isMarketRegionPickerAvailable
  }
  
  public func setToken(_ token: Token) {
    self.token = token
    self.tokenAmount = 0
    start()
  }
  
  public func getToken() -> Token {
    token
  }
  
  public func getTokenAmount() -> BigUInt {
    tokenAmount
  }
  
  public func start() {
    Task {
      currency = await currencyStore.getActiveCurrency()
      await MainActor.run {
        updateMaximumFractionDigits()
        updateRates()
        updateInputValue()
        updateConvertedValue()
        didUpdateTokenAmount()
      }
    }
    Task {
      if let cachedMethods = try? buySellMethodsService.getFiatMethods() {
        let models = await mapFiatMethods(cachedMethods)
        didUpdateMethods?(models, cachedMethods.layoutByCountry)
      }
      
      do {
        let models = try await loadFiatMethods()
        didUpdateMethods?(models.0, models.1)
      } catch {
        didUpdateMethods?([], [])
      }
    }
  }
  
  public func getActiveCurrency() async -> Currency {
    await currencyStore.getActiveCurrency()
  }
  
  public func toggleMode() {
    isTokenAmountInput.toggle()
  }
  
  public func toggleMax() {
    isMax.toggle()
  }
  
  public func setInput(_ input: String) {
    if isTokenAmountInput {
      let (amount, _) = convertInputStringToAmount(
        input: input,
        targetFractionalDigits: tokenFractionDigits
      )
      self.tokenAmount = amount
      updateConvertedValue()
    } else {
      let (amount, fractionalDigits) = convertInputStringToAmount(
        input: input,
        targetFractionalDigits: tokenFractionDigits
      )
      let converted = convertCurrencyAmountToToken(
        amount: amount,
        fractionalDigits: fractionalDigits
      )
      self.tokenAmount = converted.0.short(to: converted.1 - tokenFractionDigits)
      updateConvertedValue()
    }
  }
}

private extension BuySellOperatorController {
  func updateInputValue() {
    if isTokenAmountInput {
      let formatted = amountFormatter.formatAmount(
        tokenAmount,
        fractionDigits: tokenFractionDigits,
        maximumFractionDigits: tokenFractionDigits
      )
      didUpdateInputValue?(formatted)
      didUpdateInputSymbol?(tokenSymbol)
    } else {
      let converted = convertTokenAmountToCurrency(amount: tokenAmount)
      let formatted = amountFormatter.formatAmount(
        converted.0,
        fractionDigits: converted.1,
        maximumFractionDigits: 2
      )
      didUpdateInputValue?(formatted)
      didUpdateInputSymbol?(currency.code)
    }
  }
  
  func updateConvertedValue() {
    if isTokenAmountInput {
      let converted = convertTokenAmountToCurrency(amount: tokenAmount)
      let formatted = amountFormatter.formatAmount(
        converted.0,
        fractionDigits: converted.1,
        maximumFractionDigits: 2
      )
      didUpdateConvertedValue?("\(formatted) \(currency.code)")
    } else {
      let formatted = amountFormatter.formatAmount(
        tokenAmount,
        fractionDigits: tokenFractionDigits,
        maximumFractionDigits: 2
      )
      didUpdateConvertedValue?("\(formatted) \(tokenSymbol)")
    }
  }
  
  func convertTokenAmountToCurrency(amount: BigUInt) -> (BigUInt, Int) {
    if let rate {
      return rateConverter.convert(
        amount: amount,
        amountFractionLength: tokenFractionDigits,
        rate: rate
      )
    } else {
      return (0, 2)
    }
  }
  
  func convertCurrencyAmountToToken(amount: BigUInt, fractionalDigits: Int) -> (BigUInt, Int) {
    if let rate {
      let reversedRate = Rates.Rate(currency: currency, rate: 1/rate.rate, diff24h: nil)
      return rateConverter.convert(amount: amount, amountFractionLength: fractionalDigits, rate: reversedRate)
    } else {
      return (0, fractionalDigits)
    }
  }
  
  func didChangeInputMode() {
    updateMaximumFractionDigits()
    updateInputValue()
    updateConvertedValue()
    didUpdateIsTokenPickerAvailable?(isTokenAmountInput)
  }

  func updateMaximumFractionDigits() {
    if isTokenAmountInput {
      switch token {
      case .ton:
        didUpdateMaximumFractionDigits?(TonInfo.fractionDigits)
      case .jetton(let jettonItem):
        didUpdateMaximumFractionDigits?(jettonItem.jettonInfo.fractionDigits)
      }
    } else {
      didUpdateMaximumFractionDigits?(2)
    }
  }
  
  func updateRates() {
    let rates: [Rates.Rate]
    switch token {
    case .ton:
      rates = ratesStore.getRates(jettons: []).ton
    case .jetton(let jettonItem):
      rates = ratesStore.getRates(jettons: [jettonItem.jettonInfo]).jettonsRates.first(where: { $0.jettonInfo == jettonItem.jettonInfo })?.rates ?? []
    }
    self.rate = rates.first(where: { $0.currency == currency })
  }
  
  func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    guard !input.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = input.components(separatedBy: fractionalSeparator)
    guard components.count < 3 else {
      return (0, targetFractionalDigits)
    }
    
    var fractionalDigits = 0
    if components.count == 2 {
        let fractionalString = components[1]
        fractionalDigits = fractionalString.count
    }
    let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
    let bigIntValue = BigUInt(stringLiteral: components.joined() + zeroString)
    return (bigIntValue, targetFractionalDigits)
  }
  
  func didUpdateTokenAmount() {
    let balance: Balance
    do {
      balance = try balanceStore.getBalance(wallet: wallet).balance
    } catch {
      balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
    }
    
    updateRemaining(balance: balance)
    validate(balance: balance)
  }
  
  func validate(balance: Balance) {
    let isEmptyInput = tokenAmount.isZero
    guard !isEmptyInput else {
      didUpdateIsContinueEnabled?(false)
      return
    }
    let isBalanceValid = validateBalance(balance: balance)
    
    didUpdateIsContinueEnabled?(isBalanceValid)
  }
  
  func validateBalance(balance: Balance) -> Bool {
    switch token {
    case .ton:
      return BigUInt(balance.tonBalance.amount) >= tokenAmount
    case .jetton(let jettonItem):
      let jettonBalanceAmount = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
      return jettonBalanceAmount >= tokenAmount
    }
  }
  
  func updateRemaining(balance: Balance) {
    let amount: BigUInt
    let tokenSymbol: String?
    let fractionalDigits: Int
    switch token {
    case .ton:
      amount = BigUInt(balance.tonBalance.amount)
      tokenSymbol = TonInfo.symbol
      fractionalDigits = TonInfo.fractionDigits
    case .jetton(let jettonItem):
      amount = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
      tokenSymbol = jettonItem.jettonInfo.symbol
      fractionalDigits = jettonItem.jettonInfo.fractionDigits
    }
    
    if amount >= tokenAmount {
      let remainingAmount = amount - tokenAmount
      let formatted = amountFormatter.formatAmount(
        remainingAmount,
        fractionDigits: fractionalDigits,
        maximumFractionDigits: fractionalDigits,
        symbol: tokenSymbol
      )
      didUpdateRemaining?(.remaining(formatted))
    } else {
      didUpdateRemaining?(.insufficient)
    }
  }
  
  func didToggleMax() {
    if isMax {
      let balance: Balance
      do {
        balance = try balanceStore.getBalance(wallet: wallet).balance
      } catch {
        balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
      }
      
      switch token {
      case .ton:
        tokenAmount = BigUInt(balance.tonBalance.amount)
      case .jetton(let jettonItem):
        let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })
        tokenAmount = jettonBalance?.quantity ?? 0
      }
    } else {
      tokenAmount = 0
    }
    
    updateInputValue()
    updateConvertedValue()
  }
  
  var tokenSymbol: String {
    switch token {
    case .ton:
      return TonInfo.symbol
    case .jetton(let jettonItem):
      return jettonItem.jettonInfo.symbol ?? ""
    }
  }
  
  var tokenFractionDigits: Int {
    switch token {
    case .ton:
      return TonInfo.fractionDigits
    case .jetton(let jettonItem):
      return jettonItem.jettonInfo.fractionDigits
    }
  }
  
  var currencyFractionDigits: Int {
    return 2
  }
}

private extension BigUInt {
  func short(to count: Int) -> BigUInt {
    let divider = BigUInt(stringLiteral: "1" + String(repeating: "0", count: count))
    let newValue = self / divider
    return newValue
  }
}

private extension Int {
  static let groupSize = 3
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}

private extension BuySellOperatorController {
  func loadFiatMethods() async throws -> ([[BuySellItemModel]], [FiatMethodLayout]) {
    if await !isMarketRegionPickerAvailable() {
      return try await loadFiatMethodsByLocationRequired()
    } else {
      return try await loadDefaultFiatMethods()
    }
  }

  func loadFiatMethodsByLocationRequired() async throws -> ([[BuySellItemModel]], [FiatMethodLayout])  {
    do {
      let countryCode = try await locationService.getCountryCodeByIp()
      let methods = try await buySellMethodsService.loadFiatMethods(countryCode: countryCode)
      try? buySellMethodsService.saveFiatMethods(methods)
      return (await mapFiatMethods(methods), methods.layoutByCountry)
    } catch {
      return ([], [])
    }
  }

func loadDefaultFiatMethods() async throws -> ([[BuySellItemModel]], [FiatMethodLayout])  {
  let methods = try await buySellMethodsService.loadFiatMethods(countryCode: nil)
  try? buySellMethodsService.saveFiatMethods(methods)
  return (await mapFiatMethods(methods), methods.layoutByCountry)
}

func mapFiatMethods(_ fiatMethods: FiatMethods) async -> [[BuySellItemModel]] {
  let currency = await currencyStore.getActiveCurrency()
  var sections = [[BuySellItemModel]]()
  for category in fiatMethods.categories {
    var items = [BuySellItemModel]()
    for categoryItem in category.items {
      guard availableFiatMethods.contains(categoryItem.id) else {
        continue
      }
      let item = BuySellItemModel(
        id: categoryItem.id,
        title: categoryItem.title,
        description: categoryItem.description,
        token: categoryItem.badge,
        iconURL: categoryItem.iconURL,
        actionButton: .init(title: categoryItem.actionButton.title, url: categoryItem.actionButton.url),
        infoButtons: categoryItem.infoButtons.map { .init(title: $0.title, url: $0.url) },
        actionURL: await actionUrl(for: categoryItem, currency: currency)
      )
      items.append(item)
    }
    sections.append(items)
  }
  return sections
}

func actionUrl(for item: FiatMethodItem, currency: Currency) async -> URL? {

  guard let address = try? wallet.address.toString(bounceable: false) else { return nil }
  var urlString = item.actionButton.url
  
  let currTo: String
  switch item.id {
  case "neocrypto", "moonpay":
    currTo = "TON"
  case "mercuryo":
    await handleUrlForMercuryo(urlString: &urlString, walletAddress: address)
    currTo = "TONCOIN"
  default:
    return nil
  }
  
  urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: currency.code)
  urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: currTo)
  urlString = urlString.replacingOccurrences(of: "{ADDRESS}", with: address)
  
  guard let url = URL(string: urlString) else { return nil }
  return url
}

  func handleUrlForMercuryo(urlString: inout String,
                          walletAddress: String) async {
    urlString = urlString.replacingOccurrences(of: "{TX_ID}", with: "mercuryo_\(UUID().uuidString)")
    
    let mercuryoSecret = (try? await configurationStore.getConfiguration().mercuryoSecret) ?? ""

    guard let signature = (walletAddress + mercuryoSecret).data(using: .utf8)?.sha256().hexString() else { return }
    urlString += "&signature=\(signature)"
  }

  private var availableFiatMethods: [FiatMethodItem.ID] {
      ["mercuryo", "neocrypto", "moonpay"]
  }
}
