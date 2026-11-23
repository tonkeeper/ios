import SwiftUI
import TKUIKit

#Preview("Deep Blue") {
    LedgerAccountsScreen(
        state: .preview,
        headerIcon: .close(),
        onToggle: { _ in },
        onShowMore: {},
        onAddByNumber: {},
        onContinue: {}
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Reading") {
    LedgerAccountsScreen(
        state: LedgerAccountsScreenState(accounts: [], isReading: true, canShowMore: false, isContinueEnabled: false),
        headerIcon: .close(),
        onToggle: { _ in },
        onShowMore: {},
        onAddByNumber: {},
        onContinue: {}
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Light") {
    LedgerAccountsScreen(
        state: .preview,
        headerIcon: .back(),
        onToggle: { _ in },
        onShowMore: {},
        onAddByNumber: {},
        onContinue: {}
    )
    .tkPreviewTheme(.light)
}

extension LedgerAccountsScreenState {
    static let preview = LedgerAccountsScreenState(
        accounts: [
            .init(id: 0, title: "Account 1", addresses: previewAddresses(ton: "UQBW...G_Jo · 0.585 GRAM, tokens"), isAdded: true, isSelected: false),
            .init(id: 1, title: "Account 2", addresses: previewAddresses(ton: "UQA7...Khm4 · 0.1 GRAM"), isAdded: false, isSelected: true),
            .init(id: 2, title: "Account 3", addresses: previewAddresses(ton: "UQC4...wLk7 · 0 GRAM"), isAdded: false, isSelected: false),
        ],
        isReading: false,
        canShowMore: true,
        isContinueEnabled: true
    )

    private static func previewAddresses(ton: String) -> [Account.Address] {
        [
            .init(network: "TON", value: ton),
            .init(network: "Ethereum", value: "0x28...B488"),
            .init(network: "TRON", value: "TTGi...Y6Ev"),
            .init(network: "Solana", value: "3Pjf...ACXN"),
            .init(network: "Bitcoin", value: "bc1q...nsxd"),
        ]
    }
}
