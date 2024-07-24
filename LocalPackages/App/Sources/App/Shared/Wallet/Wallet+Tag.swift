import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

extension Wallet {
  var tag: String? {
    switch kind {
    case .regular:
      return isTestnet ? "TESTNET" : nil
    case .lockup:
      return nil
    case .watchonly:
      return TKLocales.WalletTags.watch_only
    case .w5:
      return "W5"
    case .w5Beta:
      return "W5 BETA"
    case .signer:
      return "SIGNER"
    case .ledger:
      return "LEDGER"
    }
  }
}

extension Wallet {
  func copyToastConfiguration() -> ToastPresenter.Configuration {
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    
    switch kind {
    case .w5, .w5Beta:
      backgroundColor = .Accent.green
      foregroundColor = .Text.primary
    case .regular:
      if isTestnet {
        backgroundColor = .Accent.orange
        foregroundColor = .Text.primary
      } else {
        backgroundColor = .Background.contentTint
        foregroundColor = .Text.primary
      }
    case .lockup:
      backgroundColor = .Background.contentTint
      foregroundColor = .Text.primary
    case .watchonly:
      backgroundColor = .Accent.orange
      foregroundColor = .Text.primary
    case .signer:
      backgroundColor = .Accent.purple
      foregroundColor = .Text.primary
    case .ledger:
      backgroundColor = .Accent.purple
      foregroundColor = .Text.primary
    }
    
    return ToastPresenter.Configuration(
      title: TKLocales.Actions.copied,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      dismissRule: .default
    )
  }
  
  func balanceTagConfiguration() -> TKUITagView.Configuration? {
    let tag = tag
    let textColor: UIColor?
    let backgroundColor: UIColor?
    switch kind {
    case .w5, .w5Beta:
      textColor = .Accent.green
      backgroundColor = .Accent.green.withAlphaComponent(0.16)
    case .regular:
      if isTestnet {
        textColor = .Accent.orange
        backgroundColor = UIColor(hex: "332d24")
      } else {
        textColor = nil
        backgroundColor = nil
      }
    case .lockup:
      return nil
    case .watchonly:
      textColor = .Accent.orange
      backgroundColor = UIColor(hex: "332d24")
    case .signer:
      textColor = .Accent.purple
      backgroundColor = .Accent.purple.withAlphaComponent(0.16)
    case .ledger:
      textColor = .Accent.green
      backgroundColor = .Accent.green.withAlphaComponent(0.16)
    }
    
    guard let tag, let textColor, let backgroundColor else { return nil }
    
    return TKUITagView.Configuration(
      text: tag,
      textColor: textColor,
      backgroundColor: backgroundColor
    )
  }
  
  func receiveTagConfiguration() -> TKUITagView.Configuration? {
    let tag = tag
    let textColor: UIColor?
    let backgroundColor: UIColor?
    switch kind {
    case .w5, .w5Beta:
      textColor = .Accent.green
      backgroundColor = .Accent.green.withAlphaComponent(0.16)
    case .regular:
      if isTestnet {
        textColor = .black
        backgroundColor = .Accent.orange
      } else {
        textColor = nil
        backgroundColor = nil
      }
    case .lockup:
      return nil
    case .watchonly:
      textColor = .black
      backgroundColor = .Accent.orange
    case .signer:
      textColor = .Accent.purple
      backgroundColor = .Accent.purple.withAlphaComponent(0.16)
    case .ledger:
      textColor = .Accent.purple
      backgroundColor = .Accent.purple.withAlphaComponent(0.16)
    }
    
    guard let tag, let textColor, let backgroundColor else { return nil }
    
    return TKUITagView.Configuration(
      text: tag,
      textColor: textColor,
      backgroundColor: backgroundColor
    )
  }
  
  func listTagConfiguration() -> TKUITagView.Configuration? {
    let tag = tag
    let textColor: UIColor?
    let backgroundColor: UIColor?
    switch kind {
    case .w5, .w5Beta:
      textColor = .Accent.green
      backgroundColor = .Accent.green.withAlphaComponent(0.16)
    default:
      textColor = .Text.secondary
      backgroundColor = .Background.contentTint
    }
    
    guard let tag, let textColor, let backgroundColor else { return nil }

    return TKUITagView.Configuration(
      text: tag,
      textColor: textColor,
      backgroundColor: backgroundColor
    )
  }
}
