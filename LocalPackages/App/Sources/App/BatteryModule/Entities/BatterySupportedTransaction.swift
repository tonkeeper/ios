import Foundation
import TKLocalize

enum BatterySupportedTransaction: String, CaseIterable {
  case swap
  case jetton
  case nft
  
  var name: String {
    switch self {
    case .swap:
      "Swaps via Tonkeeper"
    case .jetton:
      "Token transfers"
    case .nft:
      "NFT transfers"
    }
  }
  
  func caption(chargesCount: Int) -> String {
    let perPart: String
    switch self {
    case .swap:
      perPart = "per swap"
    case .jetton:
      perPart = "per transfer"
    case .nft:
      perPart = "per transfer"
    }
    
    return "\u{2248} \(chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: chargesCount)) \(perPart)"
  }
}
