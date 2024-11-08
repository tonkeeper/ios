import Foundation
import TKLocalize

enum BatterySupportedTransaction: String, CaseIterable {
  case swap
  case jetton
  case nft
  
  var name: String {
    switch self {
    case .swap:
      TKLocales.Battery.Settings.Items.Swaps.title
    case .jetton:
      TKLocales.Battery.Settings.Items.Token.title
    case .nft:
      TKLocales.Battery.Settings.Items.Nft.title
    }
  }
  
  func caption(chargesCount: Int) -> String {
    let perPart: String
    switch self {
    case .swap:
      perPart = TKLocales.Battery.Settings.Items.Swaps.caption
    case .jetton:
      perPart = TKLocales.Battery.Settings.Items.Token.caption
    case .nft:
      perPart = TKLocales.Battery.Settings.Items.Nft.caption
    }
    
    return "\u{2248} \(chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: chargesCount)) \(perPart)"
  }
}
