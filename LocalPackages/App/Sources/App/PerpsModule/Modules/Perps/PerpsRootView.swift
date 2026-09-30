import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsRootView: View {
    @Environment(\.tkPalette) private var palette
    @ObservedObject var viewModel: PerpsViewModel
    @State private var safeAreaBottom: CGFloat = 0

    var body: some View {
        ZStack {
            palette.background.page
                .ignoresSafeArea()
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: BottomSafeAreaKey.self,
                            value: geometry.safeAreaInsets.bottom
                        )
                    }
                )

            VStack(spacing: 0) {
                header
                if viewModel.accountState.isResolving {
                    accountLoader
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Layout.sectionSpacing) {
                            balanceCard
                            openPositionsSection
                            exploreSection
                        }
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, scrollBottomInset)
                    }
                    .tkImmediateButtonPresses()
                    .ignoresSafeArea(.container, edges: .bottom)
                }
            }
        }
        .onPreferenceChange(BottomSafeAreaKey.self) { safeAreaBottom = $0 }
    }

    var scrollBottomInset: CGFloat {
        safeAreaBottom + Layout.bottomPadding
    }
}

struct BottomSafeAreaKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension PerpsRootView {
    var accountLoader: some View {
        VStack {
            Spacer()
            CircularLoader(mode: .indeterminate, preset: .medium)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    var header: some View {
        ZStack {
            VStack(spacing: Layout.headerCaptionSpacing) {
                Text(TKLocales.Perps.title)
                    .textStyle(.h3)
                    .foregroundStyle(.textPrimary)
                Button(action: { viewModel.onLearnBasics?() }) {
                    HStack(spacing: Layout.captionIconSpacing) {
                        Text(TKLocales.Perps.learnBasics)
                            .textStyle(.body2)
                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size12.informationCircle)
                            .renderingMode(.template)
                    }
                    .foregroundStyle(.accentBlue)
                }
            }

            HStack(spacing: Layout.navButtonSpacing) {
                navButton(icon: .TKUIKit.Icons.Size16.chevronLeft, circled: true) {
                    viewModel.onBack?()
                }
                Spacer()
                if viewModel.accountState.isActive {
                    navButton(icon: .TKUIKit.Icons.Size28.clockOutline, circled: false) {
                        viewModel.onHistory?()
                    }
                }
                navButton(icon: .TKUIKit.Icons.Size28.magnifyingGlassOutline, circled: false) {
                    viewModel.onSearch?()
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
        .padding(.vertical, Layout.headerVerticalPadding)
    }

    func navButton(icon: UIImage, circled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if circled {
                    Circle()
                        .fill(.backgroundContent)
                        .frame(width: Layout.navButtonSide, height: Layout.navButtonSide)
                }
                SwiftUI.Image(uiImage: icon)
                    .renderingMode(.template)
                    .foregroundStyle(circled ? palette.text.primary : palette.icon.secondary)
            }
            .frame(width: Layout.navButtonSide, height: Layout.navButtonSide)
        }
    }

    var balanceCard: some View {
        HStack(spacing: Layout.cardPadding) {
            ZStack {
                Circle()
                    .fill(balanceIconColor.opacity(balanceIconBackgroundOpacity))
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.perps)
                    .renderingMode(.template)
                    .foregroundStyle(balanceIconColor)
            }
            .frame(width: Layout.balanceIconSide, height: Layout.balanceIconSide)

            VStack(alignment: .leading, spacing: Layout.titleSubtitleSpacing) {
                Text(viewModel.accountState.portfolio?.balanceText ?? PerpsFormatting.usd(0))
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                Text(TKLocales.Perps.balance)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.top, Layout.balanceTextTopPadding)
            .padding(.bottom, Layout.balanceTextBottomPadding)

            Spacer()

            HStack(spacing: Layout.balanceButtonSpacing) {
                PerpsCircleButton(
                    icon: .TKUIKit.Icons.Size16.minus,
                    side: Layout.balanceButtonSide
                ) {
                    viewModel.onWithdraw?()
                }
                PerpsCircleButton(
                    icon: .TKUIKit.Icons.Size16.plus,
                    appearance: .accent,
                    side: Layout.balanceButtonSide
                ) {
                    viewModel.onDeposit?()
                }
            }
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .fill(.backgroundContent)
        )
    }

    @ViewBuilder
    var openPositionsSection: some View {
        if let portfolio = viewModel.accountState.portfolio,
           let total = portfolio.positionsTotal
        {
            VStack(alignment: .leading, spacing: Layout.sectionTitleSpacing) {
                Text(TKLocales.Perps.openPositions)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)

                PerpsOpenPositionsCard(
                    total: total,
                    positions: portfolio.positions,
                    onSelect: viewModel.selectMarket
                )
            }
        }
    }

    var exploreSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionTitleSpacing) {
            HStack {
                Text(TKLocales.Perps.explore)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                    .renderingMode(.template)
                    .foregroundStyle(.iconTertiary)
                Spacer()
                PerpsSortMenuButton(sort: viewModel.sort, menuPosition: .bottomRight(inset: 0), onSelect: viewModel.setSort)
            }

            switch viewModel.marketsState {
            case .loading:
                HStack {
                    Spacer()
                    CircularLoader(mode: .indeterminate, preset: .medium)
                        .padding(.vertical, Layout.cardPadding)
                    Spacer()
                }
            case let .failed(error):
                Text(error)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Layout.errorVerticalPadding)
            case let .loaded(markets, isLoadingNextPage):
                PerpsMarketRowsCard(
                    markets: markets,
                    isLoadingNextPage: isLoadingNextPage,
                    onSelect: viewModel.selectMarket,
                    onRowAppear: viewModel.rowAppeared,
                    onRowDisappear: viewModel.rowDisappeared
                )
            }
        }
    }

    var balanceIconColor: Color {
        guard viewModel.accountState.isActive else { return palette.icon.secondary }
        return palette.accent.blue
    }

    var balanceIconBackgroundOpacity: Double {
        viewModel.accountState.isActive ? 0.12 : 0.16
    }
}

private enum Layout {
    static let horizontalPadding: CGFloat = 16
    static let headerVerticalPadding: CGFloat = 6
    static let headerCaptionSpacing: CGFloat = -3
    static let sectionSpacing: CGFloat = 28
    static let sectionTitleSpacing: CGFloat = 12
    static let errorVerticalPadding: CGFloat = 15
    static let bottomPadding: CGFloat = 16
    static let navButtonSide: CGFloat = 32
    static let navButtonSpacing: CGFloat = 8
    static let captionIconSpacing: CGFloat = 4
    static let cardPadding: CGFloat = 16
    static let titleSubtitleSpacing: CGFloat = -4
    static let balanceTextTopPadding: CGFloat = -2
    static let balanceTextBottomPadding: CGFloat = -1
    static let cardCornerRadius: CGFloat = 16
    static let balanceIconSide: CGFloat = 44
    static let balanceButtonSide: CGFloat = 36
    static let balanceButtonSpacing: CGFloat = 12
}
