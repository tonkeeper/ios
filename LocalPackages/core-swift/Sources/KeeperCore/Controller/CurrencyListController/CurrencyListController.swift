import Foundation

public final class CurrencyListController {
  public var didUpdateCurrencyList: (([Currency]) -> Void)?
  
  public func start() {
    let availableCurrencies = getAvailableCurrencies()
    didUpdateCurrencyList?(availableCurrencies)
  }
}

private extension CurrencyListController {
  func getAvailableCurrencies() -> [Currency] {
    return Currency.allCases.lazy
      .filter { !excludedCurrencies.contains($0) }
  }
  
  private var excludedCurrencies: [Currency] {
    [.TON]
  }
}
