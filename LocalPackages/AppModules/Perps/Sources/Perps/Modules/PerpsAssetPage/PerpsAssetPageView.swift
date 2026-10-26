import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit

@MainActor
public protocol PerpsAssetPageViewModeling: ObservableObject {
    var state: PerpsAssetPageState { get }
    var tradeToast: PerpsAssetPageTradeToast? { get }
    var chartMarkers: [PerpsChartPositionMarker] { get }
    var onBack: (() -> Void)? { get }

    func onAppear()
    func onDisappear()
    func perpetualInfo()
    func riskDisclosure()
    func retry()
    func long()
    func short()
    func edit()
    func cashOut()
    func share()
    func adjustMargin()
    func autoClose()
    func limitOrder(_ orderIndex: Int64)
    func editLimitOrder(_ orderIndex: Int64)
    func cancelLimitOrder(_ orderIndex: Int64)
    func seeAllHistory()
    func selectHistory(_ id: String)
}

public struct PerpsAssetPageView<ViewModel: PerpsAssetPageViewModeling, ChartViewModel: PerpsChartViewModeling>: View {
    @ObservedObject private var viewModel: ViewModel
    @ObservedObject private var chartViewModel: ChartViewModel
    @State private var safeAreaBottom: CGFloat = 0
    @State private var showSizeInToken = false

    public init(viewModel: ViewModel, chartViewModel: ChartViewModel) {
        self.viewModel = viewModel
        self.chartViewModel = chartViewModel
    }

    public var body: some View {
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
                    onPerpetualInfo: { viewModel.perpetualInfo() }
                )
                content
            }

            if let ready = viewModel.state.ready {
                PerpsAssetStickyActions(
                    actions: ready.actions,
                    isLimitOrderBusy: ready.isLimitOrderBusy,
                    onLong: { viewModel.long() },
                    onShort: { viewModel.short() },
                    onEdit: { viewModel.edit() },
                    onCashOut: { viewModel.cashOut() },
                    onEditLimitOrder: { viewModel.editLimitOrder($0) },
                    onCancelLimitOrder: { viewModel.cancelLimitOrder($0) }
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
                onSeeAllHistory: { viewModel.seeAllHistory() },
                onSelectHistory: { viewModel.selectHistory($0) },
                onRiskDisclosure: { viewModel.riskDisclosure() }
            )
        }
    }
}
