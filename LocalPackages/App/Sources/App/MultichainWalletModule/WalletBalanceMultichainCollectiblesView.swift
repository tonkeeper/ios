import SwiftUI
import TKLocalize
import TKUIKit

struct WalletBalanceMultichainCollectiblesView: View {
    @ObservedObject var viewModel: WalletBalanceMultichainCollectiblesViewModel
    var body: some View {
        switch viewModel.state {
        case let .items(content):
            section {
                cardsRow(content)
            }
        case .allHidden:
            section {
                allHiddenRow
            }
        case .empty:
            EmptyView()
        }
    }

    private func section(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            content()
        }
    }

    private var sectionHeader: some View {
        ListTitleView(
            config: .text(
                TKLocales.Collectibles.title,
                accessory: nil,
                titleAction: {
                    viewModel.onTapOpenCollectibles?()
                }
            )
        ).padding(.horizontal, Layout.horizontalInset)
    }

    private func cardsRow(
        _ content: WalletBalanceMultichainCollectiblesViewModel.Content
    ) -> some View {
        horizontalCardsScroll {
            ForEach(content.items) { item in
                NFTCard(
                    content: NFTCardContent(
                        id: item.id,
                        title: item.title,
                        subtitle: item.subtitle,
                        subtitleColor: item.subtitleColor,
                        imageSource: item.imageSource,
                        isSecureMode: item.isSecureMode,
                        isOnSale: item.isOnSale
                    ),
                    imageSize: Layout.cardSize,
                    action: {
                        viewModel.selectItem(id: item.id)
                    }
                )
            }

            if content.showsSeeAllButton {
                seeAllButton
            }
        }
    }

    private var seeAllButton: some View {
        IconButtonView(
            config: .content(
                IconButtonViewContent(
                    icon: .TKUIKit.Icons.Size16.chevronRight,
                    title: TKLocales.Trade.AssetDetails.Common.seeAll
                )
            ),
            action: {
                viewModel.onTapOpenCollectibles?()
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(width: Layout.cardWidth, height: Layout.cardHeight, alignment: .top)
    }

    private var allHiddenRow: some View {
        SetupCell(
            content: SetupCellContent(
                icon: SetupCellContent.Icon(
                    image: .TKUIKit.Icons.Size28.eyeClosedOutline,
                    tintColor: .iconSecondary,
                    backgroundColor: .backgroundContentTint
                ),
                title: TKLocales.WalletBalanceList.AllCollectiblesHidden.title,
                subtitle: SetupCellContent.Subtitle(
                    text: TKLocales.WalletBalanceList.AllCollectiblesHidden.subtitle
                ),
                accessory: .none
            ),
            onTap: {
                viewModel.onTapOpenCollectibles?()
            }
        )
        .asCellsGroup(config: Layout.allHiddenGroupConfig)
        .padding(.horizontal, Layout.horizontalInset)
    }

    private func horizontalCardsScroll<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Layout.cardSpacing, content: content)
                .padding(.horizontal, Layout.horizontalInset)
        }
        .tkImmediateButtonPresses()
    }
}

private extension WalletBalanceMultichainCollectiblesView {
    enum Layout {
        static let cardSize: NFTImageView.Size = .small
        static let horizontalInset: CGFloat = 16
        static let cardSpacing: CGFloat = 8
        static let cardWidth: CGFloat = cardSize.configuration.cardWidth
        static let cardHeight: CGFloat = cardSize.configuration.cardHeight
        static let allHiddenGroupConfig = CellsGroupModifier.Config(horizontalPadding: 0)
    }
}
