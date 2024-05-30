import Foundation

struct StonfiPairs: Codable {
  let expirationDate: Date
  let pairs: [[String]]
  let pairsSet: Set<String>
  
  public var isValid: Bool {
    !pairsSet.isEmpty && expirationDate.timeIntervalSinceNow > 0
  }
  
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
