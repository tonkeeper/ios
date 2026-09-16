import SwiftUI
import TKUIKit
import UIKit

@available(iOS 17.0, *)
#Preview("Purchases") {
    SettingsPurchasesScreen(
        state: .preview,
        onBack: {},
        onCopy: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

private extension SettingsPurchasesScreenState {
    static let preview = SettingsPurchasesScreenState(
        title: "Purchases",
        sections: [
            Section(
                id: "visible",
                title: "Visible",
                items: [
                    previewItem(
                        id: "annihilation",
                        title: "Annihilation",
                        subtitle: "12 tokens",
                        control: Item.Control(kind: .hide, action: {})
                    ),
                    previewItem(
                        id: "whales",
                        title: "TON Whales",
                        subtitle: "Single token",
                        control: Item.Control(kind: .hide, action: {})
                    ),
                ],
                showAllButton: ShowAllButton(title: "Show all", action: {})
            ),
            Section(
                id: "hidden",
                title: "Hidden",
                items: [
                    previewItem(
                        id: "diamonds",
                        title: "TON Diamonds",
                        subtitle: "3 tokens",
                        control: Item.Control(kind: .show, action: {})
                    ),
                ]
            ),
            Section(
                id: "spam",
                title: "Spam",
                items: [
                    previewItem(
                        id: "airdrop",
                        title: "Free Airdrop",
                        subtitle: "Single token",
                        showsChevron: true
                    ),
                    Item(
                        id: "allSpam",
                        image: .icon(.TKUIKit.Icons.Size44.exclamationMark),
                        title: "All spam",
                        subtitle: "128 tokens",
                        showsChevron: true,
                        action: {}
                    ),
                ]
            ),
        ]
    )

    static func previewItem(
        id: String,
        title: String,
        subtitle: String,
        control: Item.Control? = nil,
        showsChevron: Bool = false
    ) -> Item {
        Item(
            id: id,
            image: .url(nil),
            title: title,
            subtitle: subtitle,
            control: control,
            showsChevron: showsChevron,
            action: {}
        )
    }
}
