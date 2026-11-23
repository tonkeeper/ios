import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("More row", traits: .fixedLayout(width: 390, height: 120)) {
    VStack(spacing: 0) {
        WalletSectionMoreCell(
            title: "More Positions",
            previewAvatars: [
                .image(.TKUIKit.Icons.Size44.currencyUsdt, chainIcon: .TKUIKit.Icons.Size20.ethChain),
                .image(.TKUIKit.Icons.Size44.currencyUsdt),
            ],
            limit: .top3,
            showsDivider: false,
            limitMenuIdentifier: "preview_limit",
            onTap: {},
            onSelectLimit: { _ in }
        )
    }
    .asCellsGroup(config: CellsGroupModifier.Config(horizontalPadding: 0, cornerRadius: 16, backgroundColor: .backgroundContent))
    .padding(16)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}
