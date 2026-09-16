import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct WalletMigrationConfirmationScreen: View {
    @ObservedObject var viewModel: WalletMigrationConfirmationViewModel

    @State private var scrollOffset: CGFloat = 0
    @State private var scrollContentHeight: CGFloat = 0
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var scrollToBottomRequest = 0

    var body: some View {
        VStack(spacing: 0) {
            headerView

            switch viewModel.state {
            case .loading:
                ScrollView(.vertical, showsIndicators: false) {
                    shimmerItemsList
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.bottom, Layout.scrollBottomPadding)
                }
                .tkImmediateButtonPresses()
            case .failed:
                if let config = viewModel.failurePlaceholderConfig() {
                    errorStateView(config: config)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .ready:
                readyStateScrollView
            }

            if case .failed = viewModel.state {
                EmptyView()
            } else {
                footerView
            }
        }
        .background(.backgroundPage)
        .task {
            await viewModel.start()
        }
    }
}

private extension WalletMigrationConfirmationScreen {
    var headerView: some View {
        DefaultModalCardHeader(
            config: .init(
                leftIcon: .init(
                    image: .TKUIKit.Icons.Size16.chevronLeft,
                    size: 16,
                    padding: 8,
                    onTap: { _ in
                        viewModel.back()
                    }
                ),
                title: .init(
                    text: viewModel.screenTitle
                ),
                subtitle: .init(
                    text: viewModel.screenSubtitle,
                    color: .textSecondary
                ),
                rightIcon: .close { _ in
                    viewModel.close()
                }
            )
        )
    }

    var readyStateScrollView: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                TrackableScrollView(.vertical, showsIndicators: false) {
                    readyStateContent
                        .background(
                            GeometryReader { content in
                                Color.clear.preference(
                                    key: ScrollContentHeightKey.self,
                                    value: content.size.height
                                )
                            }
                        )
                        .id(ScrollAnchor.bottom)
                } onOffsetChange: { offset in
                    scrollOffset = -offset.y
                }
                .onPreferenceChange(ScrollContentHeightKey.self) { height in
                    scrollContentHeight = height
                }
                .onAppear {
                    scrollOffset = 0
                    scrollViewportHeight = viewport.size.height
                }
                .onChange(of: viewport.size.height) { height in
                    scrollViewportHeight = height
                }
                .onChange(of: scrollToBottomRequest) { _ in
                    withAnimation(.easeInOut(duration: Layout.scrollToBottomDuration)) {
                        proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
                    }
                }
            }
        }
    }

    var readyStateContent: some View {
        VStack(spacing: 0) {
            itemsList
            if viewModel.tonFeeRowModel != nil || viewModel.tronFeeRowModel != nil {
                VStack(spacing: 0) {
                    if let tonFeeRowModel = viewModel.tonFeeRowModel {
                        MultichainSwapConfirmationFeeRow(
                            title: tonFeeRowModel.title,
                            value: tonFeeRowModel.value,
                            method: tonFeeRowModel.method,
                            subtitle: "",
                            showsDivider: viewModel.tronFeeRowModel != nil,
                            onMethodTap: tonFeeRowModel.canPickMethod
                                ? { viewModel.openTonFeeMethodPicker() }
                                : nil
                        )
                    }
                    if let tronFeeRowModel = viewModel.tronFeeRowModel {
                        MultichainSwapConfirmationFeeRow(
                            title: tronFeeRowModel.title,
                            value: tronFeeRowModel.value,
                            method: tronFeeRowModel.method,
                            subtitle: "",
                            showsDivider: false,
                            onMethodTap: tronFeeRowModel.canPickMethod
                                ? { viewModel.openTronFeeMethodPicker() }
                                : nil
                        )
                    }
                }
                .background(.backgroundContent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, Layout.feeRowTopPadding)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.scrollBottomPadding)
    }

    var showsScrollHint: Bool {
        guard case .ready = viewModel.state,
              scrollViewportHeight > 0,
              scrollContentHeight > 0
        else {
            return false
        }
        let maxOffset = scrollContentHeight - scrollViewportHeight
        guard maxOffset > Layout.scrollHintBottomTolerance else { return false }
        return scrollOffset < maxOffset - Layout.scrollHintBottomTolerance
    }

    var shimmerItemsList: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< Layout.shimmerRowsCount, id: \.self) { _ in
                TransactionCell(config: .shimmer)
            }
        }
        .asCellsGroup(config: cellsGroupConfig)
    }

    var itemsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.items.enumerated()), id: \.offset) { _, item in
                TransactionCell(
                    config: .content(item)
                )
            }
        }
        .asCellsGroup(config: cellsGroupConfig)
    }

    var cellsGroupConfig: CellsGroupModifier.Config {
        CellsGroupModifier.Config(horizontalPadding: 0)
    }

    func errorStateView(config: PlaceholderView.Config) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            PlaceholderView(config: config)
                .padding(.horizontal, Layout.errorHorizontalPadding)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var footerView: some View {
        VStack(spacing: Layout.footerSpacing) {
            footerActionContent
                .frame(height: Layout.sliderHeight)
                .animation(
                    .easeInOut(duration: Layout.errorPhaseFadeDuration),
                    value: viewModel.confirmationState
                )

            if !viewModel.totalSummary.isEmpty {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        viewModel.showMigrationInfo()
                    } label: {
                        HStack(spacing: Layout.totalSummarySpacing) {
                            Text(viewModel.totalSummary)
                                .textStyle(.body2)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size12.informationCircle)
                                .renderingMode(.template)
                        }
                        .foregroundStyle(.textSecondary)
                    }
                    .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
                    Spacer(minLength: 0)
                }
                .padding(.bottom, Layout.totalSummaryBottomInset)
            }
        }
        .padding(Layout.footerPadding)
        .background(.backgroundPage.opacity(0.96), ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) {
            scrollHintView
                .alignmentGuide(.top) { $0[.bottom] }
                .opacity(showsScrollHint ? 1 : 0)
                .allowsHitTesting(showsScrollHint)
                .animation(
                    .easeInOut(duration: Layout.scrollHintFadeDuration),
                    value: showsScrollHint
                )
        }
    }

    @ViewBuilder
    var footerActionContent: some View {
        switch viewModel.confirmationState {
        case .retry:
            tryAgainButton
        case .idle, .confirming, .success, .failed:
            WalletMigrationProcessFooterRepresentable(
                sliderTitle: viewModel.sliderConfirmTitle,
                isSliderEnabled: viewModel.isSliderEnabled && !showsScrollHint,
                processState: viewModel.processState,
                successTitle: TKLocales.Result.success,
                errorTitle: TKLocales.Settings.Migration.Confirm.transactionFailed,
                processTitle: TKLocales.Settings.Migration.Confirm.sendingTransaction,
                onConfirm: viewModel.confirmSwipe
            )
        }
    }

    var tryAgainButton: some View {
        ButtonView(
            config: ButtonView.Config(
                title: TKLocales.Actions.tryAgain,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                icon: ButtonView.Icon(image: .TKUIKit.Icons.Size16.refresh),
                action: { viewModel.tryAgain() }
            )
        )
        .frame(maxHeight: .infinity, alignment: .center)
    }

    var scrollHintView: some View {
        Button {
            scrollToBottomRequest += 1
        } label: {
            WalletMigrationScrollHintView()
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        .frame(maxWidth: .infinity)
        .padding(.top, Layout.scrollHintTopPadding)
        .padding(.bottom, Layout.scrollHintBottomPadding)
        .tkScrim(.backgroundPage, edge: .bottom)
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let errorHorizontalPadding: CGFloat = 32
        static let scrollBottomPadding: CGFloat = 16
        static let feeRowTopPadding: CGFloat = 16
        static let shimmerRowsCount = 5
        static let footerPadding = EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16)
        static let footerSpacing: CGFloat = 11
        static let totalSummarySpacing: CGFloat = 4
        /// Sheds the summary's own text leading here rather than in `footerPadding`, which also
        /// sizes the footer when there is no summary row.
        static let totalSummaryBottomInset: CGFloat = -2
        static let sliderHeight: CGFloat = 88
        static let errorPhaseFadeDuration: TimeInterval = 0.4
        static let scrollHintTopPadding: CGFloat = 32
        static let scrollHintBottomPadding: CGFloat = 8
        static let scrollHintBottomTolerance: CGFloat = 8
        static let scrollHintFadeDuration: TimeInterval = 0.2
        static let scrollToBottomDuration: TimeInterval = 0.3
    }

    enum ScrollAnchor {
        static let bottom = "wallet_migration_confirmation_bottom"
    }
}

private struct WalletMigrationScrollHintView: View {
    var body: some View {
        HStack(spacing: Layout.spacing) {
            SwiftUI.Image.TKUIKit.Icons.Size16.arrowDown
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .foregroundStyle(.iconPrimary)

            Text(TKLocales.ConfirmSend.scrollHint)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(.buttonTertiaryBackground)
        .clipShape(Capsule())
        .contentShape(Capsule())
    }

    private enum Layout {
        static let spacing: CGFloat = 8
        static let iconSize: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
    }
}

private struct ScrollContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct WalletMigrationProcessFooterRepresentable: UIViewRepresentable {
    let sliderTitle: NSAttributedString
    let isSliderEnabled: Bool
    let processState: TKProcessContainerView.State
    let successTitle: String
    let errorTitle: String
    let processTitle: String
    let onConfirm: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> TKProcessContainerView {
        let processView = TKProcessContainerView(
            successTitle: successTitle,
            errorTitle: errorTitle,
            processTitle: processTitle
        )

        let slider = TKSlider()
        slider.appearance = .standart
        slider.swipeHandleAccessibilityIdentifier = "confirm_swipe"

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.addArrangedSubview(slider)

        processView.setContent(stackView)
        context.coordinator.processView = processView
        context.coordinator.slider = slider
        return processView
    }

    func updateUIView(_ uiView: TKProcessContainerView, context: Context) {
        let previousState = context.coordinator.processState
        uiView.successTitle = successTitle
        uiView.errorTitle = errorTitle
        uiView.processTitle = processTitle
        uiView.state = processState
        context.coordinator.processState = processState

        context.coordinator.slider?.title = sliderTitle
        context.coordinator.slider?.isEnable = isSliderEnabled && processState == .idle
        context.coordinator.slider?.didConfirm = onConfirm

        if processState == .idle, previousState != .idle {
            context.coordinator.slider?.reset()
        }
    }

    final class Coordinator {
        var processView: TKProcessContainerView?
        var slider: TKSlider?
        var processState: TKProcessContainerView.State = .idle
    }
}
