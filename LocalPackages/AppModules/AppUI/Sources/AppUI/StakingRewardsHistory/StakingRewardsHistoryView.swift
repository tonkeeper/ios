import SwiftUI
import TKLocalize
import TKUIKit

public struct StakingRewardsHistoryView: View {
    private let state: StakingRewardsHistoryState
    private let onBack: () -> Void
    private let onSelectPeriod: (Int) -> Void
    private let onAppearRow: (StakingRewardRowState) -> Void
    private let onRefresh: () async -> Void
    private let onRetry: () -> Void

    @State private var periodAnchorView: UIView?

    public init(
        state: StakingRewardsHistoryState,
        onBack: @escaping () -> Void,
        onSelectPeriod: @escaping (Int) -> Void,
        onAppearRow: @escaping (StakingRewardRowState) -> Void,
        onRefresh: @escaping () async -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.state = state
        self.onBack = onBack
        self.onSelectPeriod = onSelectPeriod
        self.onAppearRow = onAppearRow
        self.onRefresh = onRefresh
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    leftIcon: DefaultModalCardHeader.Icon(
                        image: .TKUIKit.Icons.Size16.chevronLeft,
                        size: 16,
                        padding: 8,
                        liquidGlassImage: .TKUIKit.Icons.Size28.chevronLeft,
                        onTap: { _ in onBack() }
                    ),
                    title: DefaultModalCardHeader.Title(text: TKLocales.StakingBalanceDetails.rewardsHistory)
                )
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    totalCard
                        .padding(.vertical, Layout.padding)
                    content
                }
                .padding(.horizontal, Layout.padding)
                .padding(.bottom, Layout.padding)
            }
            .refreshable {
                await onRefresh()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }

    @ViewBuilder
    private var content: some View {
        switch state.content {
        case .loading:
            VStack(spacing: 0) {
                ForEach(0 ..< Layout.shimmerRowsCount, id: \.self) { _ in
                    StakingRewardShimmerCell()
                }
            }
            .asCellsGroup(config: StakingRewardsHistoryLayout.cellsGroup)
        case let .rows(rows, isLoadingMore, isLoadMoreFailed):
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        StakingRewardCell(row: row, showsDivider: index < rows.count - 1)
                            .onAppear { onAppearRow(row) }
                    }
                }
                .asCellsGroup(config: StakingRewardsHistoryLayout.cellsGroup)
            }
            if isLoadingMore {
                ProgressView()
                    .padding(.vertical, Layout.padding)
            }
            if isLoadMoreFailed {
                failedCell
                    .padding(.top, Layout.padding)
            }
        case .failed:
            failedCell
        }
    }

    private var failedCell: some View {
        SetupCell(
            content: SetupCellContent(
                icon: SetupCellContent.Icon(
                    image: .TKUIKit.Icons.Size28.exclamationmarkCircle,
                    tintColor: .accentOrange,
                    backgroundColor: .accentOrange.opacity(0.12)
                ),
                title: TKLocales.StakingBalanceDetails.rewardsHistoryFailed,
                subtitle: SetupCellContent.Subtitle(text: TKLocales.StakingBalanceDetails.rewardsHistoryRetry),
                accessory: .none
            ),
            onTap: onRetry
        )
        .asCellsGroup(config: StakingRewardsHistoryLayout.cellsGroup)
    }

    private var totalCard: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(TKLocales.StakingBalanceDetails.totalReceived)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                if let total = state.total {
                    Text(total.amount)
                        .textStyle(.h2)
                        .foregroundStyle(.textPrimary)
                    Text(total.fiat)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                } else if state.content == .failed {
                    Text("—")
                        .textStyle(.h2)
                        .foregroundStyle(.textTertiary)
                } else {
                    ShimmerSwiftUIView(config: .init(color: .backgroundContentTint, cornerRadius: .value(8)))
                        .frame(width: 140, height: 32)
                    ShimmerSwiftUIView(config: .init(color: .backgroundContentTint, cornerRadius: .value(8)))
                        .frame(width: 64, height: 20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Layout.padding)
            .padding(.leading, Layout.padding)

            periodButton
                .padding(.trailing, Layout.padding)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.backgroundContent)
        )
    }

    private var periodButton: some View {
        Button {
            showPeriodMenu()
        } label: {
            HStack(spacing: 8) {
                Text(state.periods[state.selectedPeriodIndex])
                    .textStyle(.label2)
                    .lineLimit(1)
                Image(uiImage: .TKUIKit.Icons.Size16.chevronDown)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            .foregroundStyle(.buttonTertiaryForeground)
            .padding(.horizontal, Layout.padding)
            .frame(height: 36)
            .background(
                Capsule(style: .continuous)
                    .fill(.buttonTertiaryBackground)
            )
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .background(
            AnchorViewResolver { view in
                periodAnchorView = view
            }
        )
    }

    private func showPeriodMenu() {
        guard let periodAnchorView else { return }
        TKPopupMenuController.show(
            sourceView: periodAnchorView,
            position: .bottomRight(inset: 8),
            minimumWidth: 200,
            items: state.periods.enumerated().map { index, title in
                TKPopupMenuItem(title: title, selectionHandler: { onSelectPeriod(index) })
            },
            selectedIndex: state.selectedPeriodIndex
        )
    }
}

private enum Layout {
    static let padding: CGFloat = 16
    static let shimmerRowsCount = 8
}
