import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

struct AddWalletOptionPickerSection: Identifiable {
    let type: AddWalletOptionPickerSectionType
    let header: String?
    let items: [AddWalletOptionPickerItem]

    var id: AddWalletOptionPickerSectionType {
        type
    }
}

struct AddWalletOptionPickerItem: Identifiable {
    let option: AddWalletOption
    let title: String
    let subtitle: String
    let icon: UIImage
    let tag: TKTagSwiftUIViewConfig?
    let chains: [MultichainChain]

    var id: AddWalletOption {
        option
    }
}

enum AddWalletOptionPickerSectionType: CaseIterable, Hashable {
    case main
    case other

    var header: String? {
        switch self {
        case .main:
            nil
        case .other:
            TKLocales.AddWallet.Sections.otherOptions
        }
    }

    var options: [AddWalletOption] {
        switch self {
        case .main:
            [.createRegular, .createMultichain, .importRegular]
        case .other:
            [.ledger, .keystone, .signer, .importWatchOnly]
        }
    }
}

enum AddWalletOption: String, Hashable {
    case createRegular
    case createMultichain
    case importRegular
    case importWatchOnly
    case signer
    case keystone
    case ledger

    var title: String {
        switch self {
        case .createRegular:
            return TKLocales.AddWallet.Items.NewWallet.title
        case .createMultichain:
            return TKLocales.AddWallet.Items.NewWallet.title
        case .importRegular:
            return TKLocales.AddWallet.Items.ExistingWallet.title
        case .importWatchOnly:
            return TKLocales.AddWallet.Items.WatchOnly.title
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
        case .createMultichain:
            return TKLocales.AddWallet.Items.NewWallet.subtitle
        case .importRegular:
            return TKLocales.AddWallet.Items.ExistingWallet.subtitle
        case .importWatchOnly:
            return TKLocales.AddWallet.Items.WatchOnly.subtitle
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
        case .createMultichain:
            return .TKUIKit.Icons.Size28.plusOutline
        case .importRegular:
            return .TKUIKit.Icons.Size28.importWalletOutline
        case .importWatchOnly:
            return .TKUIKit.Icons.Size28.magnifyingGlassOutline
        case .signer:
            return .TKUIKit.Icons.Size28.signer
        case .keystone:
            return .TKUIKit.Icons.Size28.keystone
        case .ledger:
            return .TKUIKit.Icons.Size28.ledger
        }
    }

    var badgeTagSwiftUIConfiguration: TKTagSwiftUIViewConfig? {
        switch self {
        case .createMultichain:
            WalletMultichainPresentation.badgeTagSwiftUIConfiguration
        case .createRegular, .importRegular, .importWatchOnly, .signer, .keystone, .ledger:
            nil
        }
    }
}
