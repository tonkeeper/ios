import UIKit
import TKUIKit
import TKLocalize

struct AddWalletOptionPickerSection: Hashable {
  let item: AddWalletOptionPickerItem
}

struct AddWalletOptionPickerItem: Hashable {
  let option: AddWalletOption
  let cellConfiguration: TKListItemCell.Configuration
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(option)
  }
  
  static func == (lhs: AddWalletOptionPickerItem, rhs: AddWalletOptionPickerItem) -> Bool {
    lhs.option == rhs.option
  }
}

enum AddWalletOption: String, Hashable {
  case createRegular
  case importRegular
  case importWatchOnly
  case importTestnet
  case signer
  case keystone
  case ledger
  
  var title: String {
    switch self {
    case .createRegular:
      return TKLocales.AddWallet.Items.NewWallet.title
    case .importRegular:
      return TKLocales.AddWallet.Items.ExistingWallet.title
    case .importWatchOnly:
      return TKLocales.AddWallet.Items.WatchOnly.title
    case .importTestnet:
      return TKLocales.AddWallet.Items.Testnet.title
    case .signer:
      return TKLocales.AddWallet.Items.PairSigner.title
    case .keystone:
      return TKLocales.AddWallet.Items.PairKeystone.title
    case .ledger:
      return TKLocales.AddWallet.Items.PairLedger.title
    }
  }
  
  var subtitle: String {
    switch self {
    case .createRegular:
      return TKLocales.AddWallet.Items.NewWallet.subtitle
    case .importRegular:
      return TKLocales.AddWallet.Items.ExistingWallet.subtitle
    case .importWatchOnly:
      return TKLocales.AddWallet.Items.WatchOnly.subtitle
    case .importTestnet:
      return TKLocales.AddWallet.Items.Testnet.subtitle
    case .signer:
      return TKLocales.AddWallet.Items.PairSigner.subtitle
    case .keystone:
      return TKLocales.AddWallet.Items.PairKeystone.subtitle
    case .ledger:
      return TKLocales.AddWallet.Items.PairLedger.subtitle
    }
  }
  
  var icon: UIImage {
    switch self {
    case .createRegular:
      return .TKUIKit.Icons.Size28.plusCircle
    case .importRegular:
      return .TKUIKit.Icons.Size28.key
    case .importWatchOnly:
      return .TKUIKit.Icons.Size28.magnifyingGlass
    case .importTestnet:
      return .TKUIKit.Icons.Size28.testnet
    case .signer:
      return .TKUIKit.Icons.Size28.signer
    case .keystone:
      return .TKUIKit.Icons.Size28.keystone
    case .ledger:
      return .TKUIKit.Icons.Size28.ledger
    }
  }
}

