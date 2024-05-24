import Foundation
import TonSwift
import BigInt

public final class SwapController {
  
  actor State {
    var stonfiAssets = StonfiAssets()
    var stonfiPairs = StonfiPairs()
    
    func setStonfiAssets(_ stonfiAssets: StonfiAssets) {
      self.stonfiAssets = stonfiAssets
    }
    
    func setStonfiPairs(_ stonfiPairs: StonfiPairs) {
      self.stonfiPairs = stonfiPairs
    }
  }
  
  private var swapSimulationTask: Task<StonfiSwapSimulation, Error>?
  
  private var state = State()
  
  private let stonfiAssetsStore: StonfiAssetsStore
  private let stonfiPairsStore: StonfiPairsStore
  private let currencyStore: CurrencyStore
  private let stonfiSwapService: StonfiSwapService
  private let ratesService: RatesService
  private let stonfiAssetsLoader: StonfiAssetsLoader
  private let stonfiPairsLoader: StonfiPairsLoader
  private let stonfiMapper: StonfiMapper
  private let amountNewFormatter: AmountNewFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter
  
  init(stonfiAssetsStore: StonfiAssetsStore,
       stonfiPairsStore: StonfiPairsStore,
       currencyStore: CurrencyStore,
       stonfiSwapService: StonfiSwapService,
       ratesService: RatesService,
       stonfiAssetsLoader: StonfiAssetsLoader,
       stonfiPairsLoader: StonfiPairsLoader,
       stonfiMapper: StonfiMapper,
       amountNewFormatter: AmountNewFormatter,
       decimalAmountFormatter: DecimalAmountFormatter) {
    self.stonfiAssetsStore = stonfiAssetsStore
    self.stonfiPairsStore = stonfiPairsStore
    self.currencyStore = currencyStore
    self.stonfiSwapService = stonfiSwapService
    self.ratesService = ratesService
    self.stonfiAssetsLoader = stonfiAssetsLoader
    self.stonfiPairsLoader = stonfiPairsLoader
    self.stonfiMapper = stonfiMapper
    self.amountNewFormatter = amountNewFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
  }
  
  public func start() async {
    _ = await stonfiAssetsStore.addEventObserver(self) { [weak self] observer, event in
      guard let self else { return }
      switch event {
      case .didUpdateAssets(let assets):
        Task { await self.didUpdateAssets(assets) }
      }
    }
    
    _ = await stonfiPairsStore.addEventObserver(self) { [weak self] observer, event in
      guard let self else { return }
      switch event {
      case .didUpdatePairs(let pairs):
        Task { await self.didUpdatePairs(pairs) }
      }
    }
    
    await updateAssets()
    
    Task {
      await updatePairs()
    }
  }
  
  public func updateAssets() async {
    let assets = await stonfiAssetsStore.getAssets()
    await didUpdateAssets(assets)
  }
  
  public func updatePairs() async {
    let pairs = await stonfiPairsStore.getPairs()
    await didUpdatePairs(pairs)
  }
  
  public func getInitalSwapAsset() async -> SwapAsset? {
    let assets = await getStonfiAssets()
    guard let tonStonfiAsset = assets.items.first(where: { $0.isToncoin }) else { return nil }
    return stonfiMapper.mapStonfiAsset(tonStonfiAsset)
  }
  
  public func isPairExistsForAssets(_ assetOne: SwapAsset?, _ assetTwo: SwapAsset?) async -> Bool {
    guard let assetOne, let assetTwo else { return true }
    let pairs = await getStonfiPairs()
    return pairs.hasPair(keyOne: assetOne.contractAddress.toString(), keyTwo: assetTwo.contractAddress.toString())
  }
  
  public func simulateSwap(direction: SwapSimulationDirection,
                           amount: BigUInt,
                           sendAsset: SwapAsset,
                           recieveAsset: SwapAsset,
                           swapSettings: SwapSettingsModel) async throws -> SwapSimulationModel {
    let stonfiSimulationRequestModel = StonfiSwapSimulationRequestModel(
      fromAddress: sendAsset.contractAddress,
      toAddress: recieveAsset.contractAddress,
      amount: amount,
      slippageTolerance: swapSettings.slippageTolerance.converted,
      referralAddress: nil
    )
    
    let task = Task {
      try Task.checkCancellation()
      let stonfiSwapSimulation: StonfiSwapSimulation
      switch direction {
      case .direct:
        stonfiSwapSimulation = try await stonfiSwapService.simulateDirectSwap(stonfiSimulationRequestModel)
      case .reverse:
        stonfiSwapSimulation = try await stonfiSwapService.simulateReverseSwap(stonfiSimulationRequestModel)
      }
      try Task.checkCancellation()
      return stonfiSwapSimulation
    }
    
    swapSimulationTask?.cancel()
    swapSimulationTask = task
    
    let stonfiSwapSimulation = try await task.value
    return mapStonfiSwapSimulation(stonfiSwapSimulation, sendAsset: sendAsset, recieveAsset: recieveAsset)
  }
  
  public func convertAssetAmountToFiat(_ swapAsset: SwapAsset, amount: BigUInt) async -> String {
    let currency = await currencyStore.getActiveCurrency()
    let rates = await loadRates(jettons: swapAsset.jettons, currency: currency)
    let rate = getRate(from: rates, for: swapAsset, currency: currency)
    let converted = RateConverter().convert(amount: amount, amountFractionLength: swapAsset.fractionDigits, rate: rate)
    return convertAmountToString(
      amount: converted.amount,
      fractionDigits: converted.fractionLength,
      maximumFractionDigits: 2,
      currency: currency
    )
  }
  
  public func convertAmountToString(amount: BigUInt,
                                    fractionDigits: Int,
                                    maximumFractionDigits: Int? = nil,
                                    currency: Currency? = nil) -> String {
    let newMaximumFractionDigits = maximumFractionDigits ?? fractionDigits
    return amountNewFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: newMaximumFractionDigits,
      currency: currency
    )
  }
  
  public func convertStringToAmount(string: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    return amountNewFormatter.amount(from: string, targetFractionalDigits: targetFractionalDigits)
  }
}

private extension SwapController {
  func didUpdateAssets(_ assets: StonfiAssets) async {
    await state.setStonfiAssets(assets)
  }
  
  func didUpdatePairs(_ pairs: StonfiPairs) async {
    await state.setStonfiPairs(pairs)
  }
  
  func getStonfiAssets() async -> StonfiAssets {
    let stateAssets = await state.stonfiAssets
    if stateAssets.isValid {
      return stateAssets
    } else {
      return await stonfiAssetsStore.getAssets()
    }
  }
  
  func getStonfiPairs() async -> StonfiPairs {
    let statePairs = await state.stonfiPairs
    if statePairs.isValid {
      return statePairs
    } else {
      return await stonfiPairsStore.getPairs()
    }
  }
  
  func mapStonfiSwapSimulation(_ stonfiSwapSimulation: StonfiSwapSimulation, sendAsset: SwapAsset, recieveAsset: SwapAsset) -> SwapSimulationModel {
    let offerAmountConverted = convertAmountToString(amount: stonfiSwapSimulation.offerUnits, fractionDigits: sendAsset.fractionDigits)
    let askAmountConverted = convertAmountToString(amount: stonfiSwapSimulation.askUnits, fractionDigits: recieveAsset.fractionDigits)
    let minAskAmountConverted = convertAmountToString(amount: stonfiSwapSimulation.minAskUnits, fractionDigits: recieveAsset.fractionDigits, maximumFractionDigits: 4)
    let feeAmountConverted  = convertAmountToString(amount: stonfiSwapSimulation.feeUnits, fractionDigits: recieveAsset.fractionDigits, maximumFractionDigits: 4)
    
    let swapRate = decimalAmountFormatter.format(amount: stonfiSwapSimulation.swapRate, maximumFractionDigits: 4)
    let priceImpact = decimalAmountFormatter.format(amount: stonfiSwapSimulation.priceImpact * 100, maximumFractionDigits: 3)
    
    let blockchainFee = "0.08 - 0.25 TON".replacingOccurrences(of: ".", with: FormattersConstants.fractionalSeparator)
    
    return SwapSimulationModel(
      offerAmount: SwapSimulationModel.Amount(
        amount: stonfiSwapSimulation.offerUnits,
        converted: offerAmountConverted
      ),
      askAmount: SwapSimulationModel.Amount(
        amount: stonfiSwapSimulation.askUnits,
        converted: askAmountConverted
      ),
      minAskAmount: SwapSimulationModel.Amount(
        amount: stonfiSwapSimulation.minAskUnits,
        converted: minAskAmountConverted
      ),
      swapRate: SwapSimulationModel.Rate(value: swapRate),
      info: SwapSimulationModel.Info(
        priceImpact: priceImpact,
        minimumRecieved: minAskAmountConverted,
        liquidityProviderFee: feeAmountConverted,
        blockchainFee: blockchainFee,
        route: SwapSimulationModel.Info.Route(
          tokenSymbolSend: sendAsset.symbol,
          tokenSymbolRecieve: recieveAsset.symbol
        ),
        providerName: "STON.fi"
      )
    )
  }
  
  func loadRates(jettons: [JettonInfo], currency: Currency) async -> Rates {
    do {
      return try await ratesService.loadRates(jettons: jettons, currencies: [currency])
    } catch {
      return Rates(ton: [], jettonsRates: [])
    }
  }
  
  func getRate(from rates: Rates, for swapAsset: SwapAsset, currency: Currency) -> Rates.Rate {
    switch swapAsset {
    case .ton:
      return rates.ton.first ?? .zero(currency: currency)
    case .jetton(let assetInfo):
      return rates.jettonsRates
        .first(where: { $0.jettonInfo.address == assetInfo.contractAddress })?
        .rates.first ?? .zero(currency: currency)
    default:
      return .zero(currency: currency)
    }
  }
}

private extension SwapAsset {
  var jettons: [JettonInfo] {
    switch self {
    case .jetton(let assetInfo):
      let jettonInfo = JettonInfo(
        address: assetInfo.contractAddress,
        fractionDigits: assetInfo.fractionDigits,
        name: assetInfo.displayName,
        symbol: assetInfo.symbol,
        verification: assetInfo.isWhitelisted ? .whitelist : .none,
        imageURL: assetInfo.imageUrl
      )
      return [jettonInfo]
    default:
      return []
    }
  }
}

private extension Rates.Rate {
  static func zero(currency: Currency) -> Rates.Rate {
    Rates.Rate(currency: currency, rate: 0, diff24h: nil)
  }
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}
