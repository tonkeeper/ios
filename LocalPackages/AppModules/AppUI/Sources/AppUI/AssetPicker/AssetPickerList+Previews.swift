import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Rows", traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        AssetPickerList(rows: [
            AssetPickerRowState(id: "card", icon: .logo(nil, placeholder: .TKUIKit.Icons.Size28.purchase), title: "Credit Card"),
            AssetPickerRowState(id: "apple", icon: .logo(nil, placeholder: .TKUIKit.Icons.Size28.purchase), title: "Apple Pay"),
        ]) { _ in }
        AssetPickerList(rows: [
            AssetPickerRowState(
                id: "usdc",
                icon: .asset(.image(.TKUIKit.Icons.Size28.ton, chainIcon: .TKUIKit.Icons.Size20.ethChain)),
                title: "USDC",
                subtitle: "3 906.12 USDC · $3 905.34",
                accessory: .checkmark
            ),
            AssetPickerRowState(
                id: "usdt",
                icon: .asset(.image(.TKUIKit.Icons.Size28.ton, chainIcon: .TKUIKit.Icons.Size20.ethChain)),
                title: "USDT",
                subtitle: "Ethereum",
                accessory: .switchIcon
            ),
        ]) { _ in }
    }
    .padding(.vertical)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}
