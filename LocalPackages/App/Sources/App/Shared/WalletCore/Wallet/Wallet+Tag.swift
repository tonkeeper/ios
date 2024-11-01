import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

extension WalletContractVersion {
  var tag: String? {
    switch self {
    case .v5Beta:
      "W5 BETA"
    case .v5R1:
      "W5"
    default: nil
    }
  }
}

extension Wallet {
  var kindTag: String? {
    switch kind {
    case .regular:
      return isTestnet ? "TESTNET" : nil
    case .lockup:
      return nil
    case .watchonly:
      return TKLocales.WalletTags.watchOnly
    case .signer:
      return "SIGNER"
    case .ledger:
      return "LEDGER"
    }
  }
  
  var revisionTag: String? {
    try? contractVersion.tag
  }
}

extension Wallet {
  func copyToastConfiguration() -> ToastPresenter.Configuration {
    let backgroundColor: UIColor
    let foregroundColor: UIColor

    switch kind {
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
    default:
      backgroundColor = .Background.contentTint
      foregroundColor = .Text.primary
    }

    return ToastPresenter.Configuration(
      title: TKLocales.Toast.copied,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      dismissRule: .default
    )
  }
  
  func balanceTagConfigurations() -> [TKTagView.Configuration] {
    [revisionTagConfiguration(), balanceKindTagConfiguration()].compactMap { $0 }
  }
  
  func listTagConfigurations() -> [TKTagView.Configuration] {
    [revisionTagConfiguration(), listTagConfiguration()].compactMap { $0 }
  }

  func balanceKindTagConfiguration() -> TKTagView.Configuration? {
    let color: UIColor? = {
      switch kind {
      case .regular:
        isTestnet ? .Accent.orange : nil
      case .lockup:
        nil
      case .watchonly:
          .Accent.orange
      case .signer:
          .Accent.purple
      case .ledger:
          .Accent.green
      }
    }()
    guard let kindTag, let color else { return nil }
    return .accentTag(text: kindTag, color: color)
  }
  
  func revisionTagConfiguration() -> TKTagView.Configuration? {
    guard let revisionTag else { return nil }
    return .accentTag(text: revisionTag, color: .Accent.green)
  }

  func receiveTagConfiguration() -> TKUITagView.Configuration? {
    let tag = kindTag
    let textColor: UIColor
    let backgroundColor: UIColor
    switch kind {
    case .regular:
      if isTestnet {
        textColor = .black
        backgroundColor = .Accent.orange
      } else {
        return nil
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
    guard let tag else { return nil }

    return TKUITagView.Configuration(
      text: tag,
      textColor: textColor,
      backgroundColor: backgroundColor
    )
  }

  func listTagConfiguration() -> TKUITagView.Configuration? {
    let tag = kindTag
    let textColor: UIColor?
    let backgroundColor: UIColor?
    switch kind {
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

  func listTagConfiguration() -> TKTagView.Configuration? {
    guard let tag = kindTag else { return nil }
    return TKTagView.Configuration.tag(text: tag)
  }
}
