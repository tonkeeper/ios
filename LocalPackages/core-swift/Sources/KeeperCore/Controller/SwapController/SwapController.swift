import Foundation
import BigInt

public final class SwapController {
  
  private var stonfiPairs: StonfiPairs = StonfiPairs()
  
  private let stonfiPairsStore: StonfiPairsStore
  private let stonfiPairsService: StonfiPairsService
  private let stonfiPairsLoader: StonfiPairsLoader
  private let amountFormatter: AmountFormatter
  
  init(stonfiPairsStore: StonfiPairsStore, stonfiPairsService: StonfiPairsService, stonfiPairsLoader: StonfiPairsLoader, amountFormatter: AmountFormatter) {
    self.stonfiPairsStore = stonfiPairsStore
    self.stonfiPairsService = stonfiPairsService
    self.stonfiPairsLoader = stonfiPairsLoader
    self.amountFormatter = amountFormatter
  }
  
  public func start() async {
    _ = await stonfiPairsStore.addEventObserver(self) { [weak self] observer, event in
      guard let self else { return }
      switch event {
      case .didUpdatePairs(let pairs):
        self.didUpdatePairs(pairs)
      }
    }
    
    let storedPairs = await stonfiPairsStore.getPairs()
    if storedPairs.isValid {
      didUpdatePairs(storedPairs)
    } else {
      await stonfiPairsLoader.loadPairs()
    }
    
    // TODO: Load assets
  }
  
  public func hasPair(assetOne: SwapAsset?, assetTwo: SwapAsset?) -> Bool {
    guard let assetOne, let assetTwo else { return true }
    return stonfiPairs.hasPair(keyOne: assetOne.contractAddress, keyTwo: assetTwo.contractAddress)
  }
  
  public func convertStringToAmount(string: String, targetFractionalDigits: Int) -> (value: BigUInt, fractionalDigits: Int) {
    guard !string.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = string.components(separatedBy: fractionalSeparator)
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
  
  public func convertAmountToString(amount: BigUInt, fractionDigits: Int) -> String {
    return amountFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits
    )
  }
}

private extension SwapController {
  func didUpdatePairs(_ pairs: StonfiPairs) {
    Task { @MainActor in
      self.stonfiPairs = pairs
    }
  }
  
  func getStonfiPairs() async -> StonfiPairs {
    let storedPairs = await stonfiPairsStore.getPairs()
    if storedPairs.isValid {
      return storedPairs
    } else {
      return await loadStonfiPairs()
    }
  }
  
  func loadStonfiPairs() async -> StonfiPairs {
    do {
      return try await stonfiPairsService.loadPairs()
    } catch {
      return StonfiPairs()
    }
  }
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}
