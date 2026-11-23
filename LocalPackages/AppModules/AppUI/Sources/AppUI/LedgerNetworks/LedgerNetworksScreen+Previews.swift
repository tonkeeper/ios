import SwiftUI
import TKUIKit

#Preview("Pair Ledger") {
    LedgerNetworksScreen(
        state: .pairingPreview,
        headerIcon: .close(),
        onToggle: { _ in },
        onContinue: {}
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Add networks") {
    LedgerNetworksScreen(
        state: .addNetworksPreview,
        headerIcon: .back(),
        onToggle: { _ in },
        onContinue: {}
    )
    .tkPreviewTheme(.light)
}

extension LedgerNetworksScreenState {
    static let pairingPreview = LedgerNetworksScreenState(
        title: "Choose networks",
        description: "Select the networks you want to add to your Ledger wallet.",
        apps: [
            .init(id: "ton", title: "TON", icon: .TKUIKit.Icons.Size44.tonChain, isRequired: true, isSelected: true),
            .init(id: "sol", title: "Solana", icon: .TKUIKit.Icons.Size44.solChain, isRequired: false, isSelected: true),
            .init(id: "eth", title: "Ethereum", icon: .TKUIKit.Icons.Size44.ethChain, isRequired: false, isSelected: true),
            .init(id: "btc", title: "Bitcoin", icon: .TKUIKit.Icons.Size44.btcChain, isRequired: false, isSelected: true),
            .init(id: "tron", title: "Tron", icon: .TKUIKit.Icons.Size44.trxChain, isRequired: false, isSelected: true),
        ],
        isContinueEnabled: true
    )

    static let addNetworksPreview = LedgerNetworksScreenState(
        title: "Choose networks",
        description: "Select the networks you want to add.",
        apps: [
            .init(id: "sol", title: "Solana", icon: .TKUIKit.Icons.Size44.solChain, isRequired: false, isSelected: true),
            .init(id: "eth", title: "Ethereum", icon: .TKUIKit.Icons.Size44.ethChain, isRequired: false, isSelected: false),
            .init(id: "btc", title: "Bitcoin", icon: .TKUIKit.Icons.Size44.btcChain, isRequired: false, isSelected: false),
            .init(id: "tron", title: "Tron", icon: .TKUIKit.Icons.Size44.trxChain, isRequired: false, isSelected: false),
        ],
        isContinueEnabled: true
    )
}
