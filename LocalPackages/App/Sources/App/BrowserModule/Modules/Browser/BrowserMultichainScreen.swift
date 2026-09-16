import SwiftUI
import TKLocalize
import TKUIKit

struct BrowserMultichainScreen: View {
    @ObservedObject var viewModel: BrowserMultichainViewModelImplementation
    @ObservedObject var exploreViewModel: BrowserExploreMultichainViewModelImplementation
    @ObservedObject var connectedViewModel: BrowserConnectedMultichainViewModelImplementation

    @State private var searchText = ""
    @State private var exploreScrollToTopRequest = UUID()
    @State private var connectedScrollToTopRequest = UUID()
    var body: some View {
        VStack(spacing: 0) {
            header
            content
            searchField
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.backgroundPage)
        .onChange(of: viewModel.scrollToTopRequest) { _ in
            updateActiveTabScrollToTopRequest()
        }
    }
}

private extension BrowserMultichainScreen {
    var content: some View {
        ZStack {
            if viewModel.isExploreTabVisible {
                BrowserExploreMultichainScreen(
                    viewModel: exploreViewModel,
                    scrollToTopRequest: exploreScrollToTopRequest
                )
                .visible(viewModel.selectedTab == .explore)
            }

            BrowserConnectedMultichainScreen(
                viewModel: connectedViewModel,
                scrollToTopRequest: connectedScrollToTopRequest
            )
            .visible(viewModel.selectedTab == .connected)
        }
    }

    var header: some View {
        HStack(spacing: 0) {
            if viewModel.isExploreTabVisible {
                tabButton(
                    title: TKLocales.Browser.Tab.explore,
                    isSelected: viewModel.selectedTab == .explore,
                    action: viewModel.didTapExploreTab
                )
            }

            tabButton(
                title: TKLocales.Browser.Tab.connected,
                isSelected: viewModel.selectedTab == .connected,
                action: viewModel.didTapConnectedTab
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.headerInset)
    }

    func tabButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        ButtonView(
            config: ButtonView.Config(
                title: title,
                size: .tab,
                appearance: isSelected ? .secondary : .secondaryOverlay,
                action: action
            )
        )
    }

    var searchField: some View {
        SearchField(
            insetsModifier: {
                $0.bottom = 8
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

    func updateActiveTabScrollToTopRequest() {
        switch viewModel.selectedTab {
        case .explore:
            exploreScrollToTopRequest = UUID()
        case .connected:
            connectedScrollToTopRequest = UUID()
        }
    }

    enum Layout {
        static let headerInset = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 0)
    }
}

private extension View {
    func visible(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
    }
}
