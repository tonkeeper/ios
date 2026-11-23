import SwiftUI
import TKLocalize
import TKUIKit

public struct EarnPortfolioSectionView: View {
    private let state: EarnPortfolioSectionState
    private let onOpenCatalog: () -> Void
    private let onSelectRow: (AssetBalanceRowCellContent) -> Void
    private let onRetry: () -> Void
    private let onSelectLimit: (WalletSectionLimit) -> Void

    public init(
        state: EarnPortfolioSectionState,
        onOpenCatalog: @escaping () -> Void,
        onSelectRow: @escaping (AssetBalanceRowCellContent) -> Void,
        onRetry: @escaping () -> Void,
        onSelectLimit: @escaping (WalletSectionLimit) -> Void
    ) {
        self.state = state
        self.onOpenCatalog = onOpenCatalog
        self.onSelectRow = onSelectRow
        self.onRetry = onRetry
        self.onSelectLimit = onSelectLimit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(
                    TKLocales.Earn.Portfolio.title,
                    accessory: ListTitleView.Accessory(
                        title: state.totalBalance,
                        foregroundColor: state.isStale ? .textTertiary : .textSecondary,
                        textStyle: .label1,
                        action: onOpenCatalog
                    ),
                    titleAction: onOpenCatalog
                )
            )

            VStack(spacing: 0) {
                ForEach(Array(state.rows.enumerated()), id: \.element.id) { index, row in
                    AssetBalanceRowCell(
                        config: .content(row),
                        showsDivider: state.isStale || !state.hiddenRows.isEmpty || index < state.rows.count - 1,
                        action: { onSelectRow(row) }
                    )
                }
                if !state.hiddenRows.isEmpty {
                    WalletSectionMoreCell(
                        title: TKLocales.Earn.Portfolio.morePositions,
                        previewAvatars: state.hiddenRows.prefix(2).map(\.avatarImageSource),
                        limit: state.limit,
                        showsDivider: state.isStale,
                        limitMenuIdentifier: "wallet_earn_limit",
                        onTap: onOpenCatalog,
                        onSelectLimit: onSelectLimit
                    )
                }
                if state.isStale {
                    EarnPortfolioRetryCell(title: TKLocales.Earn.Portfolio.notUpdated, onRetry: onRetry)
                }
            }
            .asCellsGroup(config: EarnPortfolioSectionLayout.cellsGroup)
        }
        .padding(.horizontal, EarnPortfolioSectionLayout.horizontalPadding)
    }
}

public struct EarnPortfolioUnavailableSectionView: View {
    private let onRetry: () -> Void

    public init(onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Earn.Portfolio.title))

            EarnPortfolioRetryCell(title: TKLocales.Earn.Portfolio.unavailable, onRetry: onRetry)
                .asCellsGroup(config: EarnPortfolioSectionLayout.cellsGroup)
        }
        .padding(.horizontal, EarnPortfolioSectionLayout.horizontalPadding)
    }
}

private struct EarnPortfolioRetryCell: View {
    let title: String
    let onRetry: () -> Void

    var body: some View {
        SetupCell(
            content: SetupCellContent(
                icon: SetupCellContent.Icon(
                    image: .TKUIKit.Icons.Size28.exclamationmarkCircle,
                    tintColor: .accentOrange,
                    backgroundColor: .accentOrange.opacity(0.12)
                ),
                title: title,
                subtitle: SetupCellContent.Subtitle(text: TKLocales.Earn.Portfolio.tapToRetry),
                accessory: .none
            ),
            onTap: onRetry
        )
    }
}

private enum EarnPortfolioSectionLayout {
    static let horizontalPadding: CGFloat = 16
    static let cellsGroup = CellsGroupModifier.Config(
        horizontalPadding: 0,
        cornerRadius: 16,
        backgroundColor: .backgroundContent
    )
}
