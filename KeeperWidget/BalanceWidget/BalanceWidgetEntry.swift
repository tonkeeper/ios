import KeeperCore
import SwiftUI
import TKLocalize
import UIKit
import WalletExtensions
import WidgetKit
import WidgetUI

struct BalanceWidgetEntry: TimelineEntry {
    let date: Date
    /// `nil` until the app has written one, as after an update the app has not been opened since.
    let snapshot: WalletWidgetSnapshot?
    /// The configured wallet, or `nil` for a widget that follows the active one.
    let configuredWalletId: String?
    let icons: [URL: UIImage]

    var wallet: WalletWidgetSnapshot.Wallet? {
        snapshot?.wallet(id: configuredWalletId)
    }

    /// Before the app has written its data, or without a wallet.
    var message: String {
        snapshot == nil ? TKLocales.Widget.openApp : TKLocales.Widget.noWallet
    }

    func url(widget: WalletWidgetLink.Widget, family: WidgetFamily, action: WalletWidgetLink.Action) -> URL? {
        WalletWidgetLink.Family(family).flatMap {
            WalletWidgetLink(widget: widget, family: $0, action: action, walletId: configuredWalletId).url
        }
    }
}

extension BalanceWidgetEntry {
    static let placeholder = BalanceWidgetEntry(
        date: Date(),
        snapshot: WalletWidgetSnapshot(
            wallets: [
                WalletWidgetSnapshot.Wallet(
                    id: "",
                    name: "Wallet",
                    emoji: "😃",
                    icon: nil,
                    total: "$8,245.60",
                    totalCompact: "$8.2K",
                    change: WalletWidgetSnapshot.Change(text: "+$124.80", isDown: false),
                    topAssets: [
                        WalletWidgetSnapshot.Asset(id: "ton/mainnet/coin", symbol: "TON", amount: "$4,950.20", iconURL: nil),
                        WalletWidgetSnapshot.Asset(id: "eth/mainnet/coin", symbol: "ETH", amount: "$2,104.40", iconURL: nil),
                        WalletWidgetSnapshot.Asset(id: "btc/mainnet/coin", symbol: "BTC", amount: "$1,191.20", iconURL: nil),
                    ],
                    updatedAt: Date(),
                    actions: Set(WalletWidgetLink.Action.allCases)
                ),
            ],
            activeWalletId: nil,
            hidesAmounts: false,
            isRampEnabled: true,
            decimalSeparator: "."
        ),
        configuredWalletId: nil,
        icons: [:]
    )
}

extension WalletWidgetSnapshot.Wallet {
    /// Qualified: the SiriKit intent generates a `WidgetWallet` of its own.
    var widgetWallet: WidgetUI.WidgetWallet {
        WidgetUI.WidgetWallet(name: name, emoji: emoji, icon: icon.flatMap(WalletIcon.Image.init(rawValue:))?.swiftUIImage)
    }
}
