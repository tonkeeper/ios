import Foundation

protocol AmountInputUnit {
  var inputSymbol: AmountInputSymbol { get }
  var fractionalDigits: Int { get }
  var symbol: String { get }
}
