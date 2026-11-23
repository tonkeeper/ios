import SwiftUI
import TKLocalize
import TKUIKit

public struct PerpsRootView<ViewModel: PerpsRootViewModeling>: View {
    @Environment(\.tkPalette) private var palette
    @ObservedObject private var viewModel: ViewModel
    @State private var safeAreaBottom: CGFloat = 0

    public init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
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
                TrackableScrollView(showsIndicators: false) {
                    VStack(spacing: Layout.sectionSpacing) {
                        if viewModel.isRegionRestricted {
                            regionRestrictionBanner
                        } else {
                            VStack(spacing: -12) {
                                balanceCard.zIndex(1)
                                if let model = viewModel.depositStatus, !viewModel.accountState.isResolving {
                                    PerpsDepositStatusRow(model: model)
                                }
                            }
                        }
                        openPositionsSection
                        limitOrdersSection
                        exploreSection
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.bottom, scrollBottomInset)
                } onOffsetChange: { _ in
                    viewModel.depositStatus?.didInteract()
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .simultaneousGesture(TapGesture().onEnded { viewModel.depositStatus?.didInteract() })
        .onPreferenceChange(BottomSafeAreaKey.self) { safeAreaBottom = $0 }
    }

    var scrollBottomInset: CGFloat {
        safeAreaBottom + Layout.bottomPadding
    }
}

public struct BottomSafeAreaKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension PerpsRootView {
    var header: some View {
        ZStack {
            if let withdrawStatus = viewModel.withdrawStatus {
                PerpsRootHeaderTitle(status: withdrawStatus) { headerTitle }
            } else {
                headerTitle
            }

            HStack(spacing: Layout.navButtonSpacing) {
                navButton(icon: .TKUIKit.Icons.Size16.chevronLeft, circled: true) {
                    viewModel.onBack?()
                }
                .accessibilityIdentifier("perps_back")
                Spacer()
                if viewModel.accountState != .inactive {
                    navButton(icon: .TKUIKit.Icons.Size28.clockOutline, circled: false) {
                        viewModel.onHistory?()
                    }
                    .accessibilityIdentifier("perps_history")
                }
                navButton(icon: .TKUIKit.Icons.Size28.magnifyingGlassOutline, circled: false) {
                    viewModel.onSearch?()
                }
                .accessibilityIdentifier("perps_search")
            }
            .padding(.horizontal, Layout.horizontalPadding)
        }
        .padding(.vertical, Layout.headerVerticalPadding)
    }

    var headerTitle: some View {
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
                if viewModel.accountState.isResolving {
                    PerpsSkeletonBar(width: Layout.balanceSkeletonWidth)
                        .frame(height: Layout.balanceSkeletonLineHeight, alignment: .center)
                } else {
                    Text(viewModel.accountState.portfolio?.balanceText ?? viewModel.zeroBalanceText)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                }
                Text(TKLocales.Perps.balance)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.top, Layout.balanceTextTopPadding)
            .padding(.bottom, Layout.balanceTextBottomPadding)

            Spacer()

            if viewModel.accountState.isResolving {
                Capsule()
                    .fill(.backgroundContentTint)
                    .frame(width: Layout.balanceButtonsSkeletonWidth, height: Layout.balanceButtonSide)
            } else {
                balanceButtons
            }
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .fill(.backgroundContent)
        )
    }

    var regionRestrictionBanner: some View {
        NotificationBanner(
            content: NotificationBannerContent(
                title: TKLocales.Perps.RegionRestricted.title,
                description: TKLocales.Perps.RegionRestricted.banner,
                state: .accentOrange,
                buttonTitle: TKLocales.Perps.RegionRestricted.learnMore
            ),
            onButtonTap: { viewModel.onRegionRestrictionInfo?() }
        )
        .accessibilityIdentifier("perps_region_restricted")
    }

    var balanceButtons: some View {
        HStack(spacing: Layout.balanceButtonSpacing) {
            PerpsCircleButton(
                icon: .TKUIKit.Icons.Size16.minus,
                appearance: .neutral,
                side: Layout.balanceButtonSide
            ) {
                viewModel.onWithdraw?()
            }
            .accessibilityIdentifier("perps_balance_withdraw")
            PerpsCircleButton(
                icon: .TKUIKit.Icons.Size16.plus,
                appearance: .accent,
                side: Layout.balanceButtonSide
            ) {
                viewModel.onDeposit?()
            }
            .accessibilityIdentifier("perps_balance_deposit")
        }
    }

    @ViewBuilder
    var openPositionsSection: some View {
        if viewModel.loadingPositionsCount > 0 {
            openPositionsBlock {
                PerpsOpenPositionsSkeleton(count: viewModel.loadingPositionsCount)
            }
        } else if let portfolio = viewModel.accountState.portfolio,
                  let total = portfolio.positionsTotal
        {
            openPositionsBlock {
                PerpsOpenPositionsCard(
                    total: total,
                    positions: portfolio.positions,
                    onSelect: viewModel.selectMarket
                )
            }
        }
    }

    func openPositionsBlock(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionTitleSpacing) {
            Text(TKLocales.Perps.openPositions)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
            content()
        }
    }

    @ViewBuilder
    var limitOrdersSection: some View {
        if let orders = viewModel.accountState.portfolio?.limitOrders, !orders.isEmpty {
            VStack(alignment: .leading, spacing: Layout.sectionTitleSpacing) {
                Text(TKLocales.Perps.Asset.limitOrders)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)

                PerpsLimitOrdersCard(orders: orders, onSelect: viewModel.selectMarket)
            }
        }
    }

    var exploreSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionTitleSpacing) {
            HStack {
                Button(action: { viewModel.onSearch?() }) {
                    HStack {
                        Text(TKLocales.Perps.explore)
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)
                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                            .renderingMode(.template)
                            .foregroundStyle(.iconTertiary)
                    }
                }
                Spacer()
                PerpsSortMenuButton(sort: viewModel.sort, menuPosition: .bottomRight(inset: 0), onSelect: viewModel.setSort)
            }

            switch viewModel.marketsState {
            case .loading:
                PerpsSkeletonRowsCard()
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
        guard viewModel.accountState.isActive || viewModel.accountState.isResolving else { return palette.icon.secondary }
        return palette.accent.blue
    }

    var balanceIconBackgroundOpacity: Double {
        viewModel.accountState.isActive || viewModel.accountState.isResolving ? 0.12 : 0.16
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
    static let balanceSkeletonWidth: CGFloat = 76
    static let balanceSkeletonLineHeight: CGFloat = 24
    static let balanceButtonsSkeletonWidth: CGFloat = 84
}
