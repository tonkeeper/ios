import SwiftUI
import TKUIKit

struct BrowserConnectedMultichainScreen: View {
    @ObservedObject var viewModel: BrowserConnectedMultichainViewModelImplementation
    let scrollToTopRequest: UUID
    var body: some View {
        Group {
            switch viewModel.viewState {
            case let .empty(title, caption):
                emptyView(title: title, caption: caption)
            case .loading, .data:
                scrollableContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.backgroundPage)
    }
}

private extension BrowserConnectedMultichainScreen {
    var scrollableContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(Layout.topID)

                    content
                }
                .frame(maxWidth: .infinity)
            }
            .tkImmediateButtonPresses()
            .onChange(of: scrollToTopRequest) { _ in
                withAnimation {
                    proxy.scrollTo(Layout.topID, anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    var content: some View {
        switch viewModel.viewState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, Layout.loadingTopPadding)
        case let .data(items):
            appsGrid(items)
                .padding(.horizontal, Layout.gridHorizontalPadding)
                .padding(.bottom, Layout.gridBottomPadding)
        case .empty:
            EmptyView()
        }
    }

    func appsGrid(_ items: [BrowserConnectedAppItem]) -> some View {
        LazyVGrid(columns: Layout.gridColumns, spacing: Layout.gridSpacing) {
            ForEach(items) { item in
                Button {} label: {
                    ServiceCardView(
                        config: .content(
                            ServiceCardContent(
                                title: item.name,
                                titleColor: .textSecondary,
                                imageSource: .url(item.iconURL, chainIcon: item.chain?.tokenIcon20)
                            )
                        ),
                        avatarSize: .dapp,
                        avatarShape: .rectangle(cornerRadius: 16),
                        height: 104
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(ServiceCardHighlightStyle())
                .simultaneousGesture(interactionGesture(for: item))
            }
        }
    }

    func interactionGesture(for item: BrowserConnectedAppItem) -> some Gesture {
        TapGesture()
            .exclusively(before: LongPressGesture(minimumDuration: Layout.disconnectLongPressDuration))
            .onEnded { value in
                switch value {
                case .first:
                    viewModel.selectApp(item)
                case .second:
                    viewModel.requestDisconnect(item)
                }
            }
    }

    func emptyView(title: String, caption: String) -> some View {
        PlaceholderView(
            config: PlaceholderView.Config(
                lottieResource: .apps,
                title: title,
                subtitle: caption
            )
        )
        .padding(.horizontal, Layout.emptyHorizontalPadding)
        .padding(.bottom, Layout.emptyBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    enum Layout {
        static let topID = "browserConnectedTop"
        static let loadingTopPadding: CGFloat = 48
        static let gridHorizontalPadding: CGFloat = 10
        static let gridBottomPadding: CGFloat = 16
        static let emptyHorizontalPadding: CGFloat = 32
        static let emptyBottomPadding: CGFloat = 42
        static let disconnectLongPressDuration = 0.5
        static let gridSpacing: CGFloat = 0
        static let gridColumnCount = 4
        static let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: gridSpacing),
            count: gridColumnCount
        )
    }
}
