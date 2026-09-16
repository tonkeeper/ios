import Combine
import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct TradeAssetsListContentView: View {
    private enum Layout {
        static let skeletonRowCount = 8
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 24
        static let pageLoaderVerticalPadding: CGFloat = 24
        static let scrollGestureDistance: CGFloat = 1

        static let interactivePlaceholderTopPadding: CGFloat = 30
        static let defaultPlaceholderTopPadding: CGFloat = 48
    }

    private enum Content {
        case skeleton
        case notFound(subtitle: String)
        case error(subtitle: String?)
        case list(
            assets: [TradingAsset],
            currency: Currency,
            isLoadingMore: Bool
        )
    }

    @ObservedObject var viewModel: TradeAssetsListQueryViewModel
    let onOpenAsset: (TradingAsset) -> Void
    let onScrollStarted: () -> Void

    var body: some View {
        Group {
            switch content {
            case .skeleton:
                skeleton
            case let .notFound(subtitle):
                notFoundPlaceholder(subtitle: subtitle)
            case let .error(subtitle):
                errorPlaceholder(subtitle: subtitle)
            case let .list(assets, currency, isLoadingMore):
                assetsList(
                    assets: assets,
                    currency: currency,
                    isLoadingMore: isLoadingMore
                )
            }
        }
        .onReceive(viewModel.$state.dropFirst()) { state in
            guard case let .failed(rowData, message) = state,
                  !rowData.assets.isEmpty
            else {
                return
            }
            ToastPresenter.showToast(
                configuration: .defaultConfiguration(
                    text: message ?? TKLocales.Trade.Assets.Errors.load
                )
            )
        }
    }

    func retry() {
        Task {
            await viewModel.refresh()
        }
    }
}

private extension TradeAssetsListContentView {
    private var content: Content {
        switch viewModel.state {
        case .idle:
            return .skeleton
        case let .refreshing(rowData, _):
            if rowData == .initial {
                return .skeleton
            } else if rowData.assets.isEmpty {
                return .notFound(subtitle: viewModel.emptyPlaceholderSubtitle)
            } else {
                return .list(
                    assets: rowData.assets,
                    currency: rowData.currency,
                    isLoadingMore: false
                )
            }
        case let .loaded(rowData):
            if rowData.assets.isEmpty {
                return .notFound(subtitle: viewModel.emptyPlaceholderSubtitle)
            } else {
                return .list(
                    assets: rowData.assets,
                    currency: rowData.currency,
                    isLoadingMore: false
                )
            }
        case let .loadingMore(rowData, _):
            return .list(
                assets: rowData.assets,
                currency: rowData.currency,
                isLoadingMore: true
            )
        case let .failed(rowData, _):
            if rowData.assets.isEmpty {
                return .error(subtitle: TKLocales.Trade.Placeholder.errorSubtitle)
            } else {
                return .list(
                    assets: rowData.assets,
                    currency: rowData.currency,
                    isLoadingMore: false
                )
            }
        }
    }

    var dividerInset: CGFloat {
        16
    }

    var rowCornerRadius: CGFloat {
        16
    }

    func list<T: Identifiable>(
        content: [T],
        showsLoadingMore: Bool,
        hasSeparators: Bool,
        @ViewBuilder row: @escaping (T) -> some View
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(content.enumerated()), id: \.element.id) { index, value in
                        Group {
                            if hasSeparators {
                                row(value)
                                    .applySeparatorIfNeeded(index: index, total: content.count, leadingInset: dividerInset)
                            } else {
                                row(value)
                            }
                        }.roundIfNeeded(index: index, total: content.count, radius: rowCornerRadius)
                    }
                }

                if showsLoadingMore {
                    CircularLoader(
                        mode: .indeterminate,
                        preset: .medium
                    )
                    .padding(.vertical, Layout.pageLoaderVerticalPadding)
                }
            }
            .padding(.bottom, Layout.bottomPadding)
        }
        .tkImmediateButtonPresses()
        .clipShape(
            RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous)
        )
        .padding(.horizontal, Layout.horizontalPadding)
        .ignoresSafeArea(edges: .bottom)
        .simultaneousGesture(
            DragGesture(minimumDistance: Layout.scrollGestureDistance)
                .onChanged { _ in
                    onScrollStarted()
                }
        )
        .refreshable {
            await Task {
                await MinimumRefreshDurationBehavior.perform {
                    await viewModel.refresh()
                }
            }.value
        }
    }
}

extension TradeAssetsListContentView {
    struct SkeletonAssetId: Identifiable {
        var id: Int
    }

    private var skeleton: some View {
        list(
            content: (0 ..< Layout.skeletonRowCount).map(SkeletonAssetId.init),
            showsLoadingMore: false,
            hasSeparators: false
        ) { _ in
            TradeAssetCell(
                config: .shimmer
            )
        }
    }
}

extension TradeAssetsListContentView {
    private func assetsList(
        assets: [TradingAsset],
        currency: Currency,
        isLoadingMore: Bool
    ) -> some View {
        list(
            content: assets,
            showsLoadingMore: isLoadingMore,
            hasSeparators: true
        ) { asset in
            TradeAssetCell(
                config: viewModel.cellConfig(for: asset, currency: currency)
            ) {
                onOpenAsset(asset)
            }
            .id(asset.id)
            .onAppear {
                viewModel.loadNextPageIfNeeded(currentAsset: asset)
            }
        }
    }
}

extension TradeAssetsListContentView {
    private func placeholder(config: PlaceholderView.Config) -> some View {
        VStack(spacing: 0) {
            PlaceholderView(config: config)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(
            .top,
            config.button == nil
                ? Layout.defaultPlaceholderTopPadding
                : Layout.interactivePlaceholderTopPadding
        )
    }

    private func notFoundPlaceholder(subtitle: String) -> some View {
        placeholder(
            config: PlaceholderView.Config(
                lottieResource: .magnifyingGlass,
                title: TKLocales.Trade.Placeholder.notFoundTitle,
                subtitle: subtitle
            )
        )
    }

    private func errorPlaceholder(subtitle: String?) -> some View {
        placeholder(
            config: PlaceholderView.Config(
                lottieResource: .exclamationmarkCircle,
                title: TKLocales.Trade.Placeholder.errorTitle,
                subtitle: subtitle ?? TKLocales.Trade.Placeholder.errorSubtitle,
                button: PlaceholderView.ButtonConfig(
                    title: TKLocales.Actions.retry,
                    icon: .TKUIKit.Icons.Size16.refresh,
                    action: retry
                )
            )
        )
    }
}
