import SwiftUI
import TKLocalize
import TKUIKit

struct WalletBalanceMultichainAssetsListView: View {
    @ObservedObject var viewModel: WalletBalanceMultichainAssetsListViewModel
    let showsSkeleton: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsSkeleton {
                listTitle
                cellsGroup {
                    skeletonRows
                }
            } else {
                switch viewModel.presentation {
                case .error:
                    errorPlaceholder
                case .allAssetsHidden:
                    listTitle
                    cellsGroup {
                        SetupCell(content: allAssetsHiddenCellContent)
                    }
                case let .rows(rows):
                    listTitle
                    cellsGroup {
                        assetRows(rows)
                    }
                }
            }
        }
    }

    private func cellsGroup(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .asCellsGroup(config: CellsGroupModifier.Config(horizontalPadding: 0, cornerRadius: 16, backgroundColor: .backgroundContent))
    }

    private func assetRows(_ rows: [WalletBalanceMultichainAssetsListViewModel.Row]) -> some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
            let showsDivider = index < rows.count - 1
            switch item {
            case let .asset(row):
                AssetBalanceRowCell(
                    config: .content(row),
                    showsDivider: showsDivider,
                    action: {
                        viewModel.selectAsset(row: row)
                    },
                    commentAction: viewModel.commentAction(for: row)
                )
            case let .moreAssets(previewAvatars):
                WalletBalanceMoreAssetsCell(
                    previewAvatars: previewAvatars,
                    showsDivider: showsDivider,
                    action: {
                        withAnimation(Layout.expandAnimation) {
                            viewModel.expandMoreAssets()
                        }
                    }
                )
            }
        }
    }

    private var errorPlaceholder: some View {
        PlaceholderView(
            config: PlaceholderView.Config(
                lottieResource: .exclamationmarkCircle,
                title: TKLocales.Trade.Placeholder.errorTitle,
                subtitle: TKLocales.Trade.Placeholder.errorSubtitle,
                button: PlaceholderView.ButtonConfig(
                    title: TKLocales.Actions.retry,
                    icon: .TKUIKit.Icons.Size16.refresh,
                    action: {
                        viewModel.onRetry?()
                    }
                )
            )
        )
        .frame(maxWidth: .infinity)
        .padding(.top, Layout.errorTopPadding)
    }

    private var skeletonRows: some View {
        ForEach(0 ..< Layout.skeletonRowCount, id: \.self) { _ in
            AssetBalanceRowCell(
                config: .shimmer,
                showsDivider: false
            )
        }
    }

    private var listTitle: some View {
        ListTitleView(
            config: listTitleConfig
        )
        .padding(.trailing, 7)
    }

    private var listTitleConfig: ListTitleView.Config {
        if showsSkeleton {
            return .shimmer(hasAccessory: true)
        }

        return .text(
            TKLocales.Trade.Assets.title,
            accessory: manageAccessory,
            titleAction: viewModel.onTapOpenAssets
        )
    }

    private var manageAccessory: ListTitleView.Accessory? {
        guard viewModel.canManage else { return nil }
        return ListTitleView.Accessory(
            title: TKLocales.WalletBalanceList.ManageButton.title,
            icon: .TKUIKit.Icons.Size16.sliders,
            foregroundColor: .textSecondary,
            textStyle: .label2,
            action: {
                viewModel.onTapManage?()
            }
        )
    }

    private var allAssetsHiddenCellContent: SetupCellContent {
        SetupCellContent(
            icon: SetupCellContent.Icon(
                image: .TKUIKit.Icons.Size28.eyeClosedOutline,
                tintColor: .iconSecondary,
                backgroundColor: .backgroundContentTint
            ),
            title: TKLocales.WalletBalanceList.AllAssetsHidden.title,
            subtitle: SetupCellContent.Subtitle(
                text: TKLocales.WalletBalanceList.AllAssetsHidden.subtitle
            ),
            accessory: .none
        )
    }
}

private extension WalletBalanceMultichainAssetsListView {
    enum Layout {
        static let errorTopPadding: CGFloat = 32
        static let expandAnimation: Animation = .easeInOut(duration: 0.25)
        static let skeletonRowCount = 10
    }
}
