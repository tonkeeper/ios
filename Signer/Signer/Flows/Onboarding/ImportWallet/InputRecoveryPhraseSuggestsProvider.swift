import Foundation
import TKScreenKit
import TonSwift

struct InputRecoveryPhraseSuggestsProvider: TKInputRecoveryPhraseSuggestsProvider {
  func suggestsFor(input: String) -> [String] {
    guard !input.isEmpty else { return [] }
    let prefixCount = input.count
    return Array(Mnemonic.words
      .filter { $0.prefix(prefixCount) == input }
      .prefix(3))
  }
}
