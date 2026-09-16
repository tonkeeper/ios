import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

private extension TradingAssetLinkKind {
    var image: SwiftUI.Image {
        switch self {
        case .telegram:
            SwiftUI.Image.TKUIKit.Icons.Size16.telegram
        case .x:
            SwiftUI.Image.TKUIKit.Icons.Size16.x
        case .facebook:
            SwiftUI.Image.TKUIKit.Icons.Size16.facebook
        case .instagram:
            SwiftUI.Image.TKUIKit.Icons.Size16.instagram
        case .discord:
            SwiftUI.Image.TKUIKit.Icons.Size16.discord
        case .getgems:
            SwiftUI.Image.TKUIKit.Icons.Size16.getgems
        case .github:
            SwiftUI.Image.TKUIKit.Icons.Size16.github
        case .website:
            SwiftUI.Image.TKUIKit.Icons.Size16.globe
        }
    }
}

struct TradeAssetDetailsLinksSectionView: View {
    let screen: TradeAssetDetailsScreenViewData
    let onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(
                    TKLocales.Trade.AssetDetails.Sections.links
                )
            )

            LinksListView(
                items: screen.links.map { link in
                    LinksListView.Item(
                        id: link.id,
                        icon: link.kind.image,
                        title: link.title
                    )
                },
                onOpened: { item in
                    guard
                        let link = screen.links.first(where: { $0.id == item.id }),
                        let url = link.url
                    else {
                        return
                    }
                    onOpenURL(url)
                }
            )
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

private extension TradeAssetDetailsLinksSectionView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
    }
}
