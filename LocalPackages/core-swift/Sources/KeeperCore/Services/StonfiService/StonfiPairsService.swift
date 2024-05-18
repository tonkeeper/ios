import Foundation

struct StonfiPairs: Codable {
  let expirationDate: Date
  let pairs: [[String]]
  let pairsSet: Set<String>
  
  public func hasPair(keyOne: String, keyTwo: String) -> Bool {
    if pairsSet.contains(keyOne + keyTwo) || pairsSet.contains(keyTwo + keyOne) {
      return true
    }
    return false
  }
}

extension StonfiPairs {
  init() {
    self.init(
      expirationDate: Date(timeIntervalSince1970: 0),
      pairs: [],
      pairsSet: []
    )
  }
}

protocol StonfiPairsService {
  func getPairs() async throws -> StonfiPairs
  func loadPairs() async throws -> StonfiPairs
}

final class StonfiPairsServiceImplementation: StonfiPairsService {
  private let stonfiApi: StonfiAPI
  private let stonfiPairsRepository: StonfiPairsRepository
  
  init(stonfiApi: StonfiAPI, stonfiPairsRepository: StonfiPairsRepository) {
    self.stonfiApi = stonfiApi
    self.stonfiPairsRepository = stonfiPairsRepository
  }
  
  func getPairs() async throws -> StonfiPairs {
    let assets = try stonfiPairsRepository.getPairs()
    return assets
  }
  
  func loadPairs() async throws -> StonfiPairs {
    let items = try await stonfiApi.getStonfiPairs()
    
    let pairs = StonfiPairs(
      expirationDate: Date().advanced(by: .minutes(5)),
      pairs: items,
      pairsSet: mapStonfiPairsItems(items)
    )
    
    try? stonfiPairsRepository.savePairs(pairs)
    
    return pairs
  }
}

private extension StonfiPairsServiceImplementation {
  func mapStonfiPairsItems(_ items: [[String]]) -> Set<String> {
    let flatItems: [String] = items.compactMap { pair in
      guard pair.count == 2 else { return nil }
      return pair[0] + pair[1]
    }
    return Set(flatItems)
  }
}

private extension TimeInterval {
  static func seconds(_ value: Int) -> TimeInterval {
    return TimeInterval(value)
  }
  
  static func minutes(_ value: Int) -> TimeInterval {
    return .seconds(60) * TimeInterval(value)
  }
  
  static func hours(_ value: Int) -> TimeInterval {
    return .minutes(60) * TimeInterval(value)
  }
  
  static func days(_ value: Int) -> TimeInterval {
    return .hours(24) * TimeInterval(value)
  }
}
