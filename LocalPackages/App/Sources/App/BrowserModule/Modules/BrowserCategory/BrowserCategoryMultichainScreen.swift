import SwiftUI
import TKLocalize
import TKUIKit

struct BrowserCategoryMultichainScreen: View {
    @ObservedObject var viewModel: BrowserCategoryMultichainViewModelImplementation

    @State private var searchText = ""
    var body: some View {
        VStack(spacing: 0) {
            header
            content
            searchField
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.backgroundPage)
    }
}

private extension BrowserCategoryMultichainScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: DefaultModalCardHeader.Icon(
                    image: .TKUIKit.Icons.Size16.chevronLeft,
                    size: Layout.backIconSize,
                    padding: Layout.backIconPadding,
                    onTap: { _ in
                        viewModel.didTapBackButton()
                    }
                ),
                title: DefaultModalCardHeader.Title(
                    text: viewModel.title
                ),
                height: .atLeast(Layout.headerHeight)
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if shouldShowNetworkTabs {
                    networkTabs
                } else {
                    Color.clear
                        .frame(height: Layout.listTopPaddingWithoutTabs)
                }

                appsList
                    .padding(.bottom, Layout.listBottomPadding)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .tkImmediateButtonPresses()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }

    var shouldShowNetworkTabs: Bool {
        viewModel.supportedChains.count > 1
    }

    var networkTabs: some View {
        TabCategoriesView(
            items: networkTabItems,
            initialSelection: viewModel.selectedNetworkFilter,
            onSelectionChange: { selection in
                viewModel.selectedNetworkFilter = selection
            },
            style: .secondary
        )
    }

    var networkTabItems: [TabCategoriesView<BrowserCategoryNetworkFilter>.Item] {
        [TabCategoriesView<BrowserCategoryNetworkFilter>.Item(
            id: .all,
            title: TKLocales.Browser.List.all
        )] + viewModel.supportedChains.map { chain in
            TabCategoriesView<BrowserCategoryNetworkFilter>.Item(
                id: .chain(chain),
                title: chain.shortDisplayTitle,
                image: chain.tokenIcon20
            )
        }
    }

    @ViewBuilder
    var appsList: some View {
        let apps = viewModel.visibleApps
        if !apps.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(apps.enumerated()), id: \.element.id) { index, item in
                    DAppListCell(
                        content: DAppListCellContent(
                            name: item.app.name,
                            caption: item.app.description,
                            image: .url(item.app.icon, chainIcon: viewModel.showsNetworkBadges ? item.chains.singleChainBadgeIcon : nil),
                            showSeparator: index < apps.count - 1
                        ),
                        action: {
                            viewModel.selectApp(item)
                        }
                    )
                }
            }
            .asCellsGroup()
        }
    }

    var searchField: some View {
        SearchField(
            insetsModifier: {
                $0.bottom = Layout.searchBottomInset
            },
            title: TKLocales.Browser.SearchField.placeholder,
            text: $searchText,
            allowsTextInput: false
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.didTapSearchBar()
        }
    }

    enum Layout {
        static let headerHeight: CGFloat = 64
        static let backIconSize: CGFloat = 16
        static let backIconPadding: CGFloat = 8
        static let listTopPaddingWithoutTabs: CGFloat = 10
        static let listBottomPadding: CGFloat = 16
        static let searchBottomInset: CGFloat = 8
    }
}
