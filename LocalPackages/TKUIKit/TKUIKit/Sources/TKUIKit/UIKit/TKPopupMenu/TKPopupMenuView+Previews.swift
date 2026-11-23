import SwiftUI
import UIKit

@available(iOS 17.0, *)
#Preview("Liquid Glass", traits: .fixedLayout(width: 390, height: 700)) {
    VStack(alignment: .leading, spacing: 24) {
        PopupMenuPreviewHost(
            items: [
                PopupMenuPreviewItem(title: "v3R1", value: "EQCc…9ZLD", isSelectable: true),
                PopupMenuPreviewItem(title: "v3R2", isSelectable: true),
                PopupMenuPreviewItem(title: "v4R1", isSelectable: true),
                PopupMenuPreviewItem(title: "v4R2", isSelectable: true),
            ],
            selectedIndex: 0
        )
        .frame(width: 240, height: 212)
        PopupMenuPreviewHost(
            items: [
                PopupMenuPreviewItem(title: "Share", icon: .TKUIKit.Icons.Size16.share),
                PopupMenuPreviewItem(title: "Copy link", icon: .TKUIKit.Icons.Size16.copy),
            ]
        )
        .frame(width: 216, height: 116)
        PopupMenuPreviewHost(
            items: [
                PopupMenuPreviewItem(title: "Add to favorites"),
                PopupMenuPreviewItem(title: "Hide"),
            ]
        )
        .frame(width: 184, height: 116)
        PopupMenuPreviewHost(
            items: [
                PopupMenuPreviewItem(
                    title: "Multichain wallet",
                    value: "UQDa4K_C2xY8Pq9rLmN7tB3vW6zF1hJ5sD0gK",
                    isSelectable: true
                ),
                PopupMenuPreviewItem(title: "v4R2", isSelectable: true),
            ],
            selectedIndex: 0
        )
        .frame(width: 240, height: 116)
    }
    .padding(.leading, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

private struct PopupMenuPreviewItem {
    var title: String
    var value: String?
    var icon: UIImage?
    var isSelectable = false
}

@available(iOS 17.0, *)
private struct PopupMenuPreviewHost: UIViewRepresentable {
    let items: [PopupMenuPreviewItem]
    var selectedIndex: Int?

    func makeUIView(context: Context) -> TKPopupMenuView {
        // Item models resolve their colours when made, so the theme comes first.
        TKPreview.pinTheme(.deepBlue)
        let view = TKPopupMenuView(isLiquidGlass: true)
        view.items = items.map { item in
            TKPopupMenuItemView.Model(
                title: item.title,
                value: item.value,
                description: nil,
                icon: item.icon,
                leftIcon: nil,
                isSelectable: item.isSelectable,
                isEnabled: true
            )
        }
        if let selectedIndex {
            view.selectItem(index: selectedIndex)
        }
        return view
    }

    func updateUIView(_ uiView: TKPopupMenuView, context: Context) {}
}
