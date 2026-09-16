import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

struct AddressConfiguration {
    let title: String
    let icon: UIImage
}

extension MultichainChain {
    var addressConfiguration: AddressConfiguration {
        AddressConfiguration(
            title: shortDisplayTitle,
            icon: tokenIcon20
        )
    }

    var badgeTitle: String {
        switch self {
        case .ton:
            "TON"
        case .eth:
            "ETHEREUM"
        case .btc:
            "BITCOIN"
        case .base:
            "BASE"
        case .bsc:
            "BSC"
        case .arb:
            "ARBITRUM"
        case .tron:
            "TRON"
        }
    }

    var symbol: String {
        switch self {
        case .ton:
            "TON"
        case .eth:
            "ETH"
        case .btc:
            "BTC"
        case .base:
            "BASE"
        case .bsc:
            "BSC"
        case .arb:
            "ARB"
        case .tron:
            "TRON"
        }
    }

    var tokenType: String {
        switch self {
        case .ton:
            "TON"
        case .eth:
            "ERC20"
        case .btc:
            "BTC"
        case .base:
            "ERC20"
        case .bsc:
            "BEP20"
        case .arb:
            "ERC20"
        case .tron:
            "TRC20"
        }
    }

    var tokenIcon20: UIImage {
        switch self {
        case .ton:
            .TKUIKit.Icons.Size20.tonChain
        case .eth:
            .TKUIKit.Icons.Size20.ethChain
        case .btc:
            .TKUIKit.Icons.Size20.btcChain
        case .base:
            .TKUIKit.Icons.Size20.baseChain
        case .bsc:
            .TKUIKit.Icons.Size20.bscChain
        case .arb:
            .TKUIKit.Icons.Size20.arbitrumChain
        case .tron:
            .TKUIKit.Icons.Size20.trxChain
        }
    }

    var tokenIcon44: UIImage {
        switch self {
        case .ton:
            .TKUIKit.Icons.Size44.tonChain
        case .eth:
            .TKUIKit.Icons.Size44.ethChain
        case .btc:
            .TKUIKit.Icons.Size44.btcChain
        case .base:
            .TKUIKit.Icons.Size44.baseChain
        case .bsc:
            .TKUIKit.Icons.Size44.bscChain
        case .arb:
            .TKUIKit.Icons.Size44.arbitrumChain
        case .tron:
            .TKUIKit.Icons.Size44.trxChain
        }
    }
}

extension [MultichainChain] {
    /// The app's network when it is unambiguous (exactly one); nil for multi-network or chain-agnostic apps.
    var singleChain: MultichainChain? {
        count == 1 ? first : nil
    }

    /// Icon for the network badge on an app card. Per design it is shown only when the app
    /// targets exactly one network; multi-network and chain-agnostic apps show no badge.
    var singleChainBadgeIcon: UIImage? {
        singleChain?.tokenIcon20
    }
}
