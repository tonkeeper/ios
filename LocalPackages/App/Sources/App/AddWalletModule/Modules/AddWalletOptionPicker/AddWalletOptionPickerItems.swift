import TKLocalize
import TKUIKit
import UIKit

struct AddWalletOptionPickerSection: Hashable {
    let header: String?
    let items: [AddWalletOptionPickerItem]
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
    case importTetra
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
        case .importTetra:
            return TKLocales.AddWallet.Items.Tetra.title
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
        case .importTetra:
            return TKLocales.AddWallet.Items.Tetra.subtitle
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
            return .TKUIKit.Icons.Size28.importWalletOutline
        case .importWatchOnly:
            return .TKUIKit.Icons.Size28.magnifyingGlassOutline
        case .importTestnet:
            return .TKUIKit.Icons.Size28.testnetOutline
        case .importTetra:
            return .TKUIKit.Icons.Size28.tetraOutline
        case .signer:
            return .TKUIKit.Icons.Size28.signer
        case .keystone:
            return .TKUIKit.Icons.Size28.keystone
        case .ledger:
            return .TKUIKit.Icons.Size28.ledger
        }
    }
}
