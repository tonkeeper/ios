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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Layout.sectionSpacing) {
                        balanceCard
                        exploreSection
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.bottom, scrollBottomInset)
                }
                .tkImmediateButtonPresses()
                .ignoresSafeArea(.container, edges: .bottom)
            }

            if let toast = viewModel.activationBanner {
                activationToast(toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }

            floatingButton
        }
        .onPreferenceChange(BottomSafeAreaKey.self) { safeAreaBottom = $0 }
        .animation(.easeInOut(duration: 0.2), value: viewModel.activationBanner)
    }

    var scrollBottomInset: CGFloat {
        let buttonFootprint = hasFloatingButton
            ? Layout.stickyButtonTopPadding + Layout.stickyButtonHeight
            : 0
        return safeAreaBottom + buttonFootprint + Layout.bottomPadding
    }

    var hasFloatingButton: Bool {
        viewModel.accountState.isActive || viewModel.accountState.showsActivationButton
    }
}

private struct BottomSafeAreaKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension PerpsRootView {
    @ViewBuilder
    var floatingButton: some View {
        if viewModel.accountState.isActive {
            stickyButton(title: TKLocales.Perps.deposit) {
                viewModel.onDeposit?()
            }
        } else if viewModel.accountState.showsActivationButton {
            stickyButton(
                title: TKLocales.Perps.activateAccount,
                isEnabled: viewModel.accountState.isActivationButtonEnabled
            ) {
                viewModel.activate()
            }
        }
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

    func activationToast(_ toast: PerpsViewModel.ActivationToast) -> some View {
        VStack {
            HStack(spacing: Layout.toastSpacing) {
                switch toast {
                case .activating:
                    CircularLoader(mode: .indeterminate, preset: .small)
                        .frame(width: Layout.toastIconSide, height: Layout.toastIconSide)
                case .success:
                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.checkmarkCircle)
                        .renderingMode(.template)
                        .foregroundStyle(.accentGreen)
                        .frame(width: Layout.toastIconSide, height: Layout.toastIconSide)
                }

                Text(toast.title)
                    .textStyle(.label2)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
            }
            .padding(.leading, Layout.toastLeadingPadding)
            .padding(.trailing, Layout.toastTrailingPadding)
            .frame(height: Layout.toastHeight)
            .background(
                Capsule()
                    .fill(.backgroundContentTint)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            )
            .padding(.top, Layout.toastTopPadding)

            Spacer()
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
                if let portfolio = viewModel.accountState.portfolio {
                    Text(portfolio.balanceText)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                } else {
                    Text(TKLocales.Perps.accountInactive)
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

            if viewModel.accountState.isActive {
                Button(action: { viewModel.onDeposit?() }) {
                    Text(TKLocales.Perps.deposit)
                        .textStyle(.label2)
                        .foregroundStyle(.buttonPrimaryForeground)
                        .padding(.horizontal, Layout.depositButtonHorizontalPadding)
                        .frame(height: Layout.depositButtonHeight)
                        .background(
                            Capsule().fill(.buttonPrimaryBackground)
                        )
                }
            } else if viewModel.accountState.showsActivationButton {
                Button(action: {
                    guard viewModel.accountState.isActivationButtonEnabled else { return }
                    viewModel.activate()
                }) {
                    Text(TKLocales.Perps.activate)
                        .textStyle(.label2)
                        .foregroundStyle(.buttonPrimaryForeground)
                        .opacity(primaryButtonTextOpacity(isEnabled: viewModel.accountState.isActivationButtonEnabled))
                        .padding(.horizontal, Layout.depositButtonHorizontalPadding)
                        .frame(height: Layout.depositButtonHeight)
                        .background(
                            Capsule()
                                .fill(primaryButtonBackgroundColor(isEnabled: viewModel.accountState.isActivationButtonEnabled))
                        )
                }
            }
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                .fill(.backgroundContent)
        )
    }

    var exploreSection: some View {
        VStack(alignment: .leading, spacing: Layout.exploreSpacing) {
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

    func stickyButton(title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                Button(action: {
                    guard isEnabled else { return }
                    action()
                }) {
                    Text(title)
                        .textStyle(.label1)
                        .foregroundStyle(.buttonPrimaryForeground)
                        .opacity(primaryButtonTextOpacity(isEnabled: isEnabled))
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.stickyButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                                .fill(primaryButtonBackgroundColor(isEnabled: isEnabled))
                        )
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Layout.stickyButtonTopPadding)
            }
            .background(
                LinearGradient(
                    stops: [
                        .init(color: palette.background.page.opacity(0), location: 0),
                        .init(color: palette.background.page.opacity(0.036), location: 0.13),
                        .init(color: palette.background.page.opacity(0.147), location: 0.27),
                        .init(color: palette.background.page.opacity(0.332), location: 0.40),
                        .init(color: palette.background.page.opacity(0.557), location: 0.53),
                        .init(color: palette.background.page.opacity(0.768), location: 0.67),
                        .init(color: palette.background.page.opacity(0.918), location: 0.80),
                        .init(color: palette.background.page, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    var balanceIconColor: Color {
        guard viewModel.accountState.isActive else { return palette.icon.secondary }
        return viewModel.isTestnet ? palette.accent.orange : palette.accent.blue
    }

    var balanceIconBackgroundOpacity: Double {
        viewModel.accountState.isActive ? 0.12 : 0.16
    }

    func primaryButtonBackgroundColor(isEnabled: Bool) -> Color {
        isEnabled ? palette.button.primaryBackground : palette.button.primaryBackgroundDisabled
    }

    func primaryButtonTextOpacity(isEnabled: Bool) -> Double {
        isEnabled ? 1 : Layout.disabledButtonTextOpacity
    }
}

private extension PerpsViewModel.ActivationToast {
    var title: String {
        switch self {
        case .activating:
            return TKLocales.Perps.activatingToast
        case .success:
            return TKLocales.Perps.accountActivated
        }
    }
}

private enum Layout {
    static let horizontalPadding: CGFloat = 16
    static let headerVerticalPadding: CGFloat = 6
    static let headerCaptionSpacing: CGFloat = -3
    static let sectionSpacing: CGFloat = 16
    static let exploreSpacing: CGFloat = 11
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
    static let depositButtonHeight: CGFloat = 36
    static let depositButtonHorizontalPadding: CGFloat = 16
    static let toastHeight: CGFloat = 48
    static let toastIconSide: CGFloat = 16
    static let toastSpacing: CGFloat = 8
    static let toastLeadingPadding: CGFloat = 16
    static let toastTrailingPadding: CGFloat = 24
    static let toastTopPadding: CGFloat = 8
    static let stickyButtonHeight: CGFloat = 56
    static let stickyButtonTopPadding: CGFloat = 16
    static let disabledButtonTextOpacity: Double = 0.48
}
