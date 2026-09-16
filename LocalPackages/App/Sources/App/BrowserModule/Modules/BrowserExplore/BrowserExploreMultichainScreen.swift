import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct BrowserExploreMultichainScreen: View {
    @ObservedObject var viewModel: BrowserExploreMultichainViewModelImplementation
    let scrollToTopRequest: UUID
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(Layout.topID)

                    content
                }
            }
            .tkImmediateButtonPresses()
            .refreshable {
                guard viewModel.isRefreshEnabled else {
                    return
                }
                await Task {
                    await MinimumRefreshDurationBehavior.perform {
                        await viewModel.reloadAsync()
                    }
                }.value
            }
            .onChange(of: scrollToTopRequest) { _ in
                withAnimation {
                    proxy.scrollTo(Layout.topID, anchor: .top)
                }
            }
        }
        .background(.backgroundPage)
    }
}

private extension BrowserExploreMultichainScreen {
    @ViewBuilder
    var content: some View {
        switch viewModel.viewState {
        case .empty:
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, Layout.loadingTopPadding)
        case let .content(content):
            contentView(content)
        }
    }

    func contentView(_ content: BrowserExploreContent) -> some View {
        let content = filteredContent(content)
        return VStack(spacing: 0) {
            if !content.featuredApps.isEmpty {
                BrowserExploreFeaturedCarousel(
                    apps: content.featuredApps,
                    onSelect: viewModel.selectFeaturedApp
                )
            }

            if !content.ads.isEmpty {
                adsList(content.ads)
                    .padding(.top, Layout.adsTopPadding)
            }

            ForEach(sections(content.sections, placement: .beforeNetworkTabs)) { section in
                sectionView(section)
                    .padding(.top, Layout.sectionPadding)
            }

            if viewModel.supportedChains.count > 1 {
                networkTabs
            } else {
                Color.clear
                    .frame(height: Layout.sectionPadding)
            }

            ForEach(sections(content.sections, placement: .afterNetworkTabs)) { section in
                sectionView(section)
                    .padding(.bottom, Layout.sectionPadding)
            }
        }
    }

    func sections(
        _ sections: [BrowserExploreAppsSection],
        placement: BrowserExploreAppsSection.Placement
    ) -> [BrowserExploreAppsSection] {
        sections.filter { $0.placement == placement }
    }

    var networkTabs: some View {
        TabCategoriesView(
            items: networkTabItems,
            initialSelection: viewModel.selectedNetworkFilter,
            onSelectionChange: { selection in
                viewModel.selectNetworkFilter(selection)
            },
            style: .secondary,
            insetsModifier: { insets in
                insets = Layout.networkTabsInsets
            }
        )
    }

    var networkTabItems: [TabCategoriesView<BrowserExploreNetworkFilter>.Item] {
        [TabCategoriesView<BrowserExploreNetworkFilter>.Item(
            id: .all,
            title: TKLocales.Browser.List.all
        )] + viewModel.supportedChains.map { chain in
            TabCategoriesView<BrowserExploreNetworkFilter>.Item(
                id: .chain(chain),
                title: chain.shortDisplayTitle,
                image: chain.tokenIcon20
            )
        }
    }

    func sectionView(_ section: BrowserExploreAppsSection) -> some View {
        VStack(spacing: 0) {
            if let title = section.title {
                ListTitleView(
                    config: .text(
                        title,
                        accessory: section.hasAll ? ListTitleView.Accessory(
                            title: TKLocales.Trade.AssetDetails.Common.seeAll,
                            action: {
                                viewModel.selectCategory(section.category)
                            }
                        ) : nil
                    )
                )
                .padding(.horizontal, Layout.sectionTitleHorizontalPadding)
            }

            appsGrid(section.apps)
                .padding(.horizontal, Layout.gridHorizontalPadding)
        }
    }

    func appsGrid(_ apps: [BrowserExploreAppItem]) -> some View {
        LazyVGrid(columns: Layout.gridColumns, spacing: Layout.gridSpacing) {
            ForEach(apps) { item in
                Button {
                    viewModel.selectApp(item.app)
                } label: {
                    ServiceCardView(
                        config: .content(
                            ServiceCardContent(
                                title: item.app.name,
                                titleColor: .textSecondary,
                                imageSource: .url(
                                    item.app.icon,
                                    chainIcon: viewModel.showsNetworkBadges ? item.chains.singleChainBadgeIcon : nil
                                )
                            )
                        ),
                        avatarSize: .dapp,
                        avatarShape: .rectangle(cornerRadius: 16)
                    )
                }
                .buttonStyle(ServiceCardHighlightStyle())
            }
        }
    }

    func adsList(_ ads: [BrowserExploreAdItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(ads.enumerated()), id: \.element.id) { index, item in
                BrowserExploreAdRow(
                    item: item,
                    showsDivider: index < ads.count - 1,
                    onButtonTap: {
                        viewModel.performAdButtonAction(item)
                    }
                )
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.adsCornerRadius, style: .continuous))
        .padding(.horizontal, Layout.adsHorizontalPadding)
    }

    func filteredContent(_ content: BrowserExploreContent) -> BrowserExploreContent {
        let chain: MultichainChain?
        if case let .chain(selected) = viewModel.selectedNetworkFilter {
            chain = selected
        } else {
            chain = nil
        }

        return BrowserExploreContent(
            featuredApps: chain.map { c in content.featuredApps.filter { $0.chains.contains(c) } } ?? content.featuredApps,
            ads: chain.map { c in content.ads.filter { $0.app.chains.contains(c) } } ?? content.ads,
            sections: content.sections.compactMap { previewSection($0, chain: chain) }
        )
    }

    func previewSection(
        _ section: BrowserExploreAppsSection,
        chain: MultichainChain?
    ) -> BrowserExploreAppsSection? {
        let matched = chain.map { c in section.apps.filter { $0.chains.contains(c) } } ?? section.apps
        guard !matched.isEmpty else {
            return nil
        }

        let preview = previewApps(matched)
        return BrowserExploreAppsSection(
            id: section.id,
            category: section.category,
            placement: section.placement,
            title: section.title,
            hasAll: matched.count > preview.count,
            apps: preview
        )
    }

    func previewApps(_ apps: [BrowserExploreAppItem]) -> [BrowserExploreAppItem] {
        let rows = apps.chunked(into: Layout.gridColumnCount).prefix(Layout.previewMaxRows)
        var result = [BrowserExploreAppItem]()
        for (rowIndex, row) in rows.enumerated() where rowIndex == 0 || row.count > Layout.minAppsInSecondRow {
            result.append(contentsOf: row)
        }
        return result
    }

    enum Layout {
        static let topID = "browserExploreTop"
        static let loadingTopPadding: CGFloat = 48
        static let adsTopPadding: CGFloat = 16
        static let sectionPadding: CGFloat = 16
        static let networkTabsInsets = EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16)
        static let sectionTitleHorizontalPadding: CGFloat = 16
        static let gridHorizontalPadding: CGFloat = 10
        static let gridSpacing: CGFloat = 0
        static let gridColumnCount = 4
        static let previewMaxRows = 2
        static let minAppsInSecondRow = 2
        static let adsCornerRadius: CGFloat = 16
        static let adsHorizontalPadding: CGFloat = 16
        static let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: gridSpacing),
            count: gridColumnCount
        )
    }
}

private struct BrowserExploreAdRow: View {
    let item: BrowserExploreAdItem
    let showsDivider: Bool
    let onButtonTap: () -> Void
    var body: some View {
        HStack(spacing: Layout.contentSpacing) {
            AssetAvatarView(
                imageSource: .url(item.app.icon),
                size: .small,
                shape: .rectangle(cornerRadius: Layout.avatarCornerRadius)
            )

            VStack(alignment: .leading, spacing: Layout.textSpacing) {
                Text(item.app.name)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(Layout.titleLineLimit)

                if let description = item.app.description {
                    Text(description)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(Layout.descriptionLineLimit)
                }
            }

            Spacer(minLength: 0)

            if let button = item.app.button {
                ButtonView(
                    config: ButtonView.Config(
                        title: button.title,
                        size: .small,
                        appearance: .tertiary,
                        action: onButtonTap
                    )
                )
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(height: Layout.height)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
                    .padding(.leading, Layout.dividerLeadingPadding)
            }
        }
    }
}

private extension BrowserExploreAdRow {
    enum Layout {
        static let contentSpacing: CGFloat = 12
        static let avatarCornerRadius: CGFloat = 12
        static let textSpacing: CGFloat = -2
        static let titleLineLimit = 1
        static let descriptionLineLimit = 1
        static let horizontalPadding: CGFloat = 16
        static let height: CGFloat = 76
        static let dividerLeadingPadding: CGFloat = 72
    }
}
