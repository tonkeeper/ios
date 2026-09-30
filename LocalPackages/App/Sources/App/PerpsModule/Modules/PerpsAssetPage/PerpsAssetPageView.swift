import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsAssetPageView: View {
    @ObservedObject var viewModel: PerpsAssetPageViewModel
    @ObservedObject var chartViewModel: PerpsChartViewModel
    @State private var safeAreaBottom: CGFloat = 0
    @State private var showSizeInToken = false

    var body: some View {
        ZStack {
            TKColor.backgroundPage
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
                PerpsAssetPageHeader(
                    title: viewModel.state.ready?.title ?? "",
                    onBack: { viewModel.onBack?() },
                    onPerpetualInfo: { viewModel.perpetualInfo() },
                    onMore: { viewModel.more() }
                )
                content
            }

            if let ready = viewModel.state.ready {
                PerpsAssetStickyActions(
                    actions: ready.actions,
                    onLong: { viewModel.long() },
                    onShort: { viewModel.short() },
                    onEdit: { viewModel.edit() },
                    onCashOut: { viewModel.cashOut() }
                )
            }

            if let toast = viewModel.tradeToast {
                VStack {
                    PerpsAssetTradeToast(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.horizontal, 56)
                .padding(.top, 8)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.tradeToast)
        .onPreferenceChange(BottomSafeAreaKey.self) { safeAreaBottom = $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            PerpsAssetLoadingView()
        case .failed:
            PerpsAssetFailedView(
                title: TKLocales.Perps.Asset.failedTitle,
                onRetry: { viewModel.retry() }
            )
        case .notFound:
            PerpsAssetFailedView(title: TKLocales.Perps.Asset.notFoundTitle, onRetry: nil)
        case let .ready(ready):
            PerpsAssetPageReadyView(
                ready: ready,
                chartViewModel: chartViewModel,
                chartMarkers: viewModel.chartMarkers,
                safeAreaBottom: safeAreaBottom,
                showSizeInToken: $showSizeInToken,
                onShare: { viewModel.share() },
                onAdjustMargin: { viewModel.adjustMargin() },
                onAutoClose: { viewModel.autoClose() },
                onLimitOrder: { viewModel.limitOrder($0) },
                onSeeAllHistory: { viewModel.seeAllHistory() }
            )
        }
    }
}
