import SwiftUI
import TKLocalize
import TKUIKit

struct CollectiblesListView: View {
    @ObservedObject var viewModel: CollectiblesListViewModelImplementation
    @Environment(\.tkPalette) private var palette

    var body: some View {
        ZStack {
            palette.background.page
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private extension CollectiblesListView {
    enum ScreenContent {
        case skeleton
        case empty
        case list(items: [CollectiblesListItem])
    }

    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: viewModel.hasBackButton ? .back(accessibilityIdentifier: "header_back") { _ in
                    viewModel.tapBack()
                } : nil,
                title: DefaultModalCardHeader.Title(
                    text: TKLocales.Collectibles.title
                ),
                subtitle: viewModel.isMultichain ? DefaultModalCardHeader.Subtitle(
                    text: TKLocales.Collectibles.onlyTonCollectiblesForNow,
                    color: .textSecondary,
                    icon: DefaultModalCardHeader.SubtitleIcon(
                        image: .TKUIKit.Icons.Size12.informationCircle,
                        size: 12,
                        topPadding: 4
                    ),
                    onTap: {
                        viewModel.openTonCollectiblesPopup()
                    }
                ) : nil,
                rightIcon: DefaultModalCardHeader.Icon(
                    image: .TKUIKit.Icons.Size16.sliders,
                    size: Layout.iconSize,
                    padding: Layout.iconPadding,
                    accessibilityIdentifier: "header_action",
                    onTap: { _ in
                        viewModel.tapSettings()
                    }
                )
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    var content: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    Color.clear
                        .frame(height: 0)
                        .id(Layout.topID)

                    switch screenContent {
                    case .skeleton:
                        skeletonGrid(containerWidth: geometry.size.width)
                            .padding(.bottom, Layout.bottomPadding)
                    case .empty:
                        emptyView(availableHeight: geometry.size.height)
                    case let .list(items):
                        grid(
                            items: items,
                            containerWidth: geometry.size.width
                        )
                        .padding(.bottom, Layout.bottomPadding)
                    }
                }
                .tkImmediateButtonPresses()
                .refreshable {
                    await Task {
                        await MinimumRefreshDurationBehavior.perform {
                            await viewModel.refresh()
                        }
                    }.value
                }
                .onChange(of: viewModel.scrollToTopRequestID) { _ in
                    withAnimation {
                        proxy.scrollTo(Layout.topID, anchor: .top)
                    }
                }
            }
        }
    }

    var screenContent: ScreenContent {
        switch viewModel.state {
        case .idle:
            return .skeleton
        case let .refreshing(rowData):
            if rowData.items.isEmpty {
                return .skeleton
            } else {
                return .list(items: rowData.items)
            }
        case let .loaded(rowData):
            if rowData.items.isEmpty {
                return .empty
            } else {
                return .list(items: rowData.items)
            }
        }
    }

    func grid(
        items: [CollectiblesListItem],
        containerWidth: CGFloat
    ) -> some View {
        let configuration = cardConfiguration(containerWidth: containerWidth)
        let columns = Array(
            repeating: GridItem(.fixed(configuration.cardWidth), spacing: Layout.itemSpacing),
            count: Layout.columnsCount
        )

        return LazyVGrid(columns: columns, alignment: .center, spacing: Layout.itemSpacing) {
            ForEach(items) { item in
                NFTCard(
                    config: .content(
                        NFTCardContent(
                            id: item.id,
                            title: item.title,
                            subtitle: item.subtitle,
                            subtitleColor: item.subtitleColor,
                            imageSource: item.imageSource,
                            isSecureMode: item.isSecureMode,
                            isOnSale: item.isOnSale
                        )
                    ),
                    configuration: configuration,
                    action: {
                        viewModel.selectItem(id: item.id)
                    }
                )
            }
        }
        .padding(.horizontal, Layout.horizontalInset)
        .frame(maxWidth: .infinity)
    }

    func skeletonGrid(containerWidth: CGFloat) -> some View {
        let configuration = cardConfiguration(containerWidth: containerWidth)
        let columns = Array(
            repeating: GridItem(.fixed(configuration.cardWidth), spacing: Layout.itemSpacing),
            count: Layout.columnsCount
        )

        return LazyVGrid(columns: columns, alignment: .center, spacing: Layout.itemSpacing) {
            ForEach(0 ..< Layout.skeletonCardsCount, id: \.self) { _ in
                NFTCard(
                    config: .shimmer,
                    configuration: configuration
                )
            }
        }
        .padding(.horizontal, Layout.horizontalInset)
        .frame(maxWidth: .infinity)
    }

    func emptyView(availableHeight: CGFloat) -> some View {
        Text(TKLocales.Purchases.emptyPlaceholder)
            .textStyle(.h2)
            .foregroundStyle(.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Layout.emptyHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .center)
    }

    func cardConfiguration(containerWidth: CGFloat) -> NFTImageView.Configuration {
        let totalHorizontalInset = Layout.horizontalInset * 2
        let totalSpacing = Layout.itemSpacing * CGFloat(Layout.columnsCount - 1)
        let cardWidth = max(1, floor((containerWidth - totalHorizontalInset - totalSpacing) / CGFloat(Layout.columnsCount)))
        return NFTImageView.Configuration(
            imageWidth: cardWidth,
            imageHeight: cardWidth,
            cardWidth: cardWidth,
            cardHeight: cardWidth + Layout.cardTextHeight
        )
    }
}

private extension CollectiblesListView {
    enum Layout {
        static let topID = "collectibles_list_top"
        static let columnsCount = 3
        static let skeletonCardsCount = 9
        static let horizontalInset: CGFloat = 16
        static let itemSpacing: CGFloat = 8
        static let bottomPadding: CGFloat = 16
        static let emptyHorizontalPadding: CGFloat = 32
        static let iconSize: CGFloat = 16
        static let iconPadding: CGFloat = 8
        static let cardTextHeight: CGFloat = NFTImageView.Size.small.configuration.cardHeight - NFTImageView.Size.small.configuration.imageHeight
    }
}
