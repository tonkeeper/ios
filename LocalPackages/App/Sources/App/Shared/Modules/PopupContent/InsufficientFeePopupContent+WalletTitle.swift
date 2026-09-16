import KeeperCore
import SwiftUI
import WalletExtensions

extension InsufficientFeePopupContent {
    struct WalletTitle {
        let argument: String
        let icon: SwiftUI.Image?
        let name: String
        let namePlaceholder: String?
    }

    static func walletTitle(for wallet: Wallet) -> WalletTitle {
        switch wallet.icon {
        case let .emoji(emoji):
            let name = "\(emoji) \(wallet.label)"
            return WalletTitle(
                argument: name,
                icon: nil,
                name: name,
                namePlaceholder: nil
            )
        case let .icon(image):
            let namePlaceholder = "{walletName}"
            return WalletTitle(
                argument: namePlaceholder,
                icon: image.swiftUIImage,
                name: wallet.label,
                namePlaceholder: namePlaceholder
            )
        }
    }
}
