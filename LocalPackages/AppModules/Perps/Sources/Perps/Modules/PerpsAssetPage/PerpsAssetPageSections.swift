import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsAssetPageHeader: View {
    let title: String
    let onBack: () -> Void
    let onPerpetualInfo: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Text(title)
                    .textStyle(.h3)
                    .foregroundStyle(.textPrimary)
                Button(action: onPerpetualInfo) {
                    HStack(spacing: 0) {
                        Text(TKLocales.Perps.Asset.perpetual)
                            .textStyle(.body2)
                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size12.informationCircle)
                            .renderingMode(.template)
                            .padding(.leading, Layout.badgeIconSpacing)
                    }
                    .foregroundStyle(.textAccent)
                }
            }
            .padding(.horizontal, Layout.headerTitleInset)

            HStack {
                PerpsAssetHeaderButton(icon: .TKUIKit.Icons.Size16.chevronLeft, action: onBack)
                    .accessibilityIdentifier("perps_asset_back")
                Spacer()
            }
            .padding(.horizontal, Layout.headerSide)
        }
        .frame(height: Layout.headerHeight)
    }
}

private struct PerpsAssetHeaderButton: View {
    let icon: UIImage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .fill(.buttonSecondaryBackground)
                SwiftUI.Image(uiImage: icon)
                    .renderingMode(.template)
                    .foregroundStyle(.iconSecondary)
            }
            .frame(width: Layout.headerButtonSide, height: Layout.headerButtonSide)
        }
    }
}

struct PerpsAssetTradeToast: View {
    let toast: PerpsAssetPageTradeToast

    var body: some View {
        HStack(spacing: 8) {
            toastIcon
            Text(text)
                .textStyle(.label2)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.backgroundContentTint)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var toastIcon: some View {
        switch toast {
        case .progress:
            CircularLoader(mode: .indeterminate, preset: .small)
        case .success:
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.checkmarkCircle)
                .renderingMode(.template)
                .foregroundStyle(.accentGreen)
        case .failure, .unknown:
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.exclamationMarkCircle)
                .renderingMode(.template)
                .foregroundStyle(.accentRed)
        }
    }

    private var text: String {
        switch toast {
        case let .progress(text), let .success(text), let .unknown(text), let .failure(text): text
        }
    }
}

struct PerpsAssetLoadingView<ChartViewModel: PerpsChartViewModeling>: View {
    let hasPosition: Bool
    let chartViewModel: ChartViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                market
                PerpsChartView(viewModel: chartViewModel, markers: [])
                    .accessibilityHidden(true)
                PerpsAssetSeparator()
                if hasPosition {
                    position
                    history
                }
                info
            }
        }
        .allowsHitTesting(false)
        .accessibilityIdentifier("perps_asset_loading")
    }

    private var market: some View {
        VStack(alignment: .leading, spacing: Layout.marketIconSpacing) {
            PerpsSkeletonCircle(side: Layout.iconSide)
            VStack(alignment: .leading, spacing: Layout.skeletonLineSpacing) {
                PerpsSkeletonBar(width: 120, height: 24)
                HStack(spacing: Layout.deltaSpacing) {
                    PerpsSkeletonBar(width: 48)
                    PerpsSkeletonBar(width: 40)
                }
            }
            .frame(minHeight: Layout.marketContentHeight, alignment: .top)
        }
        .padding(.top, Layout.marketTopPadding)
        .padding(.bottom, Layout.marketBottomPadding)
        .padding(.horizontal, Layout.marketHorizontalPadding)
    }

    private var position: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(TKLocales.Perps.Asset.yourPosition)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Layout.listInset)
                .padding(.vertical, Layout.sectionTitleVerticalPadding)
            VStack(alignment: .leading, spacing: Layout.skeletonLineSpacing) {
                PerpsSkeletonBar(width: 80, height: 24)
                HStack(spacing: Layout.deltaSpacing) {
                    PerpsSkeletonBar(width: 40)
                    PerpsSkeletonBar(width: 32)
                }
            }
            .padding(Layout.cellPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .asCellsGroup()
            .padding(.bottom, Layout.positionCardSpacing)
            rows([
                (TKLocales.Perps.Asset.size, TKLocales.Perps.Asset.Size.hint),
                (TKLocales.Perps.Asset.liquidationPrice, TKLocales.Perps.Asset.LiquidationPrice.hint),
                (TKLocales.Perps.Asset.markPrice, TKLocales.Perps.Asset.MarkPrice.hint),
                (TKLocales.Perps.Asset.entryPrice, TKLocales.Perps.Asset.EntryPrice.hint),
                (TKLocales.Perps.Asset.funding, TKLocales.Perps.Asset.FundingRate.hint),
            ])
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Perps.Asset.transactionHistory))
                .padding(.horizontal, Layout.listInset)
            VStack(spacing: 0) {
                ForEach(0 ..< 3, id: \.self) { index in
                    if index > 0 {
                        PerpsAssetSeparator(inset: Layout.cellPadding)
                    }
                    PerpsSkeletonRow(leading: [[77], [60]], trailing: [50, 68])
                }
            }
            .asCellsGroup()
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Perps.Asset.info))
                .padding(.horizontal, Layout.listInset)
            rows([
                (TKLocales.Perps.Asset.volume24h, TKLocales.Perps.Asset.Volume24h.hint),
                (TKLocales.Perps.openInterest, TKLocales.Perps.Asset.OpenInterest.hint),
                (TKLocales.Perps.Asset.funding, TKLocales.Perps.Asset.FundingRate.hint),
            ])
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }

    private func rows(_ labels: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                if index > 0 {
                    PerpsAssetSeparator(inset: Layout.cellPadding)
                }
                HStack(spacing: 0) {
                    PerpsAssetInfoLabel(label.0, hint: label.1)
                    Spacer(minLength: Layout.rowGap)
                    PerpsSkeletonBar(width: 64)
                }
                .padding(.horizontal, Layout.cellPadding)
                .padding(.vertical, Layout.cellLabelVerticalPadding)
            }
        }
        .asCellsGroup()
    }
}

struct PerpsAssetFailedView: View {
    let title: String
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: Layout.failedSpacing) {
            Spacer()
            Text(title)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button(action: onRetry) {
                    Text(TKLocales.Perps.Asset.retry)
                        .textStyle(.label2)
                        .foregroundStyle(.buttonSecondaryForeground)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(Capsule().fill(.buttonSecondaryBackground))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct PerpsAssetPageReadyView<ChartViewModel: PerpsChartViewModeling>: View {
    let ready: PerpsAssetPageReady
    let chartViewModel: ChartViewModel
    let chartMarkers: [PerpsChartPositionMarker]
    let showsLoyaltyBanner: Bool
    let safeAreaBottom: CGFloat
    @Binding var showSizeInToken: Bool
    let onShare: () -> Void
    let onAdjustMargin: () -> Void
    let onAutoClose: () -> Void
    let onLimitOrder: (Int64) -> Void
    let onSeeAllHistory: () -> Void
    let onSelectHistory: (String) -> Void
    let onRiskDisclosure: () -> Void
    let onOpenLoyalty: () -> Void
    let onDismissLoyaltyBanner: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PerpsAssetMarketSection(ready: ready, chartViewModel: chartViewModel)
                PerpsChartView(viewModel: chartViewModel, markers: chartMarkers)
                PerpsAssetSeparator()
                if showsLoyaltyBanner {
                    PerpsAssetLoyaltyBanner(onOpen: onOpenLoyalty, onDismiss: onDismissLoyaltyBanner)
                }
                positionAndOrders
                if !ready.history.isEmpty {
                    PerpsAssetHistorySection(history: ready.history, onSeeAll: onSeeAllHistory, onSelect: onSelectHistory)
                }
                PerpsAssetInfoSection(ready: ready)
                PerpsAssetAboutSection(about: ready.about)
                PerpsAssetRiskDisclosureFootnote(action: onRiskDisclosure)
            }
            .padding(.bottom, safeAreaBottom + Layout.actionBarHeight + Layout.bottomPadding)
        }
        .tkImmediateButtonPresses()
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private var positionAndOrders: some View {
        if let position = ready.position {
            PerpsAssetPositionSection(
                position: position,
                autoClose: ready.autoClose,
                canAdjustMargin: ready.canAdjustMargin,
                canEditAutoClose: ready.canEditAutoClose,
                showSizeInToken: $showSizeInToken,
                onShare: onShare,
                onAdjustMargin: onAdjustMargin,
                onAutoClose: onAutoClose
            )
        }
        if !ready.limitOrders.isEmpty {
            PerpsAssetLimitOrdersSection(
                orders: ready.limitOrders,
                isEnabled: ready.canCancelOrders,
                isBusy: ready.isLimitOrderBusy,
                onLimitOrder: onLimitOrder
            )
        }
        if !ready.orders.isEmpty {
            PerpsAssetOrdersSection(
                triggerOrders: ready.orders,
                autoClose: ready.autoClose,
                canEditAutoClose: ready.canEditAutoClose,
                onAutoClose: onAutoClose
            )
        }
    }
}

struct PerpsAssetLoyaltyBanner: View {
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        BannerItemView(
            item: BannerItem(
                id: "loyalty",
                title: TKLocales.Loyalty.Banner.title,
                actionTitle: TKLocales.Loyalty.Banner.action,
                image: .TKUIKit.Artwork.Banners.loyalty,
                action: onOpen
            ),
            height: Layout.bannerHeight,
            onTapDismiss: onDismiss
        )
        .padding(.horizontal, Layout.listInset)
        .padding(.bottom, Layout.sectionBottomPadding)
    }
}

private struct PerpsAssetMarketSection<ChartViewModel: PerpsChartViewModeling>: View {
    let ready: PerpsAssetPageReady
    @ObservedObject var chartViewModel: ChartViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.marketIconSpacing) {
            marketIcon

            marketContent
                .frame(minHeight: Layout.marketContentHeight, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Layout.marketTopPadding)
        .padding(.bottom, Layout.marketBottomPadding)
        .padding(.horizontal, Layout.marketHorizontalPadding)
    }

    @ViewBuilder
    private var marketIcon: some View {
        if let iconURL = ready.iconURL {
            AssetAvatarView(imageSource: .url(iconURL), size: .regular)
        } else {
            ZStack {
                Circle().fill(.backgroundContentTint)
                Text(ready.iconLetter)
                    .textStyle(.h3)
                    .foregroundStyle(.textSecondary)
            }
            .frame(width: Layout.iconSide, height: Layout.iconSide)
        }
    }

    @ViewBuilder
    private var marketContent: some View {
        if let readout = chartViewModel.crosshairReadout {
            switch chartViewModel.mode {
            case .candle:
                PerpsAssetCandleCrosshairReadout(readout: readout)
            case .line:
                PerpsAssetLineCrosshairReadout(readout: readout)
            }
        } else {
            PerpsAssetPriceChangeBlock(
                price: ready.priceText,
                percent: ready.changePercentText,
                amount: ready.changeAmountText,
                isPositive: ready.isChangePositive
            )
        }
    }
}

private struct PerpsAssetPriceChangeBlock: View {
    let price: String
    let percent: String
    let amount: String
    let isPositive: Bool?

    var body: some View {
        let changeColor: TKColor = isPositive.map { $0 ? .accentGreen : .accentRed } ?? .textSecondary
        VStack(alignment: .leading, spacing: Layout.priceDeltaSpacing) {
            Text(price)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)

            HStack(spacing: Layout.deltaSpacing) {
                Text(percent)
                    .textStyle(.body2)
                    .foregroundStyle(changeColor)
                Text(amount)
                    .textStyle(.body2)
                    .foregroundStyle(changeColor)
                    .opacity(Layout.deltaAmountOpacity)
            }
        }
    }
}

private struct PerpsAssetLineCrosshairReadout: View {
    let readout: PerpsChartCrosshairReadout

    var body: some View {
        let changeColor: TKColor = readout.isPositive ? .accentGreen : .accentRed
        VStack(alignment: .leading, spacing: Layout.readoutRowSpacing) {
            Text(readout.dateTime)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
            HStack(spacing: Layout.deltaSpacing) {
                Text(readout.closeText)
                    .textStyle(.body2)
                    .foregroundStyle(.textPrimary)
                Text("\(readout.amountText) (\(readout.percentText))")
                    .textStyle(.body2)
                    .foregroundStyle(changeColor)
            }
        }
    }
}

private struct PerpsAssetCandleCrosshairReadout: View {
    let readout: PerpsChartCrosshairReadout

    var body: some View {
        let closeColor: TKColor = readout.isPositive ? .accentGreen : .accentRed
        HStack(alignment: .top, spacing: Layout.rowGap) {
            VStack(alignment: .leading, spacing: Layout.readoutRowSpacing) {
                Text(readout.dateTime)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                PerpsAssetCrosshairLeadingCell(
                    tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.open),
                    value: readout.openText
                )
                HStack(spacing: Layout.crosshairValueSpacing) {
                    PerpsAssetCrosshairLeadingTag(
                        tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.close, color: closeColor)
                    )
                    Text(readout.closeText)
                        .textStyle(.body2)
                        .foregroundStyle(.textPrimary)
                    Text(readout.percentText)
                        .textStyle(.body2)
                        .foregroundStyle(closeColor)
                }
            }
            Spacer(minLength: Layout.rowGap)
            VStack(alignment: .trailing, spacing: Layout.readoutRowSpacing) {
                PerpsAssetCrosshairTrailingCell(
                    value: readout.volumeText,
                    tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.volume)
                )
                PerpsAssetCrosshairTrailingCell(
                    value: readout.highText,
                    tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.high)
                )
                PerpsAssetCrosshairTrailingCell(
                    value: readout.lowText,
                    tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.low)
                )
            }
        }
    }
}

private struct PerpsAssetChartTag: View {
    let text: String
    var color: TKColor = .iconSecondary

    var body: some View {
        TKTagSwiftUIView(config: .init(
            text: text,
            style: .custom(
                textColor: color,
                backgroundColor: color.opacity(Layout.chipTintOpacity),
                borderColor: .clear
            ),
            textPadding: Layout.chartTagTextPadding,
            backgroundPadding: .zero,
            fillsWidth: true
        ))
    }
}

private struct PerpsAssetCrosshairLeadingCell: View {
    let tag: PerpsAssetChartTag
    let value: String

    var body: some View {
        HStack(spacing: Layout.crosshairValueSpacing) {
            PerpsAssetCrosshairLeadingTag(tag: tag)
            Text(value)
                .textStyle(.body2)
                .foregroundStyle(.textPrimary)
        }
    }
}

private struct PerpsAssetCrosshairTrailingCell: View {
    let value: String
    let tag: PerpsAssetChartTag

    var body: some View {
        HStack(spacing: Layout.crosshairValueSpacing) {
            Text(value)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
            PerpsAssetCrosshairTrailingTag(tag: tag)
        }
    }
}

private struct PerpsAssetCrosshairLeadingTag: View {
    let tag: PerpsAssetChartTag

    var body: some View {
        PerpsAssetCrosshairTagColumn(
            tag: tag,
            sizingLabels: [TKLocales.Perps.Chart.open, TKLocales.Perps.Chart.close]
        )
    }
}

private struct PerpsAssetCrosshairTrailingTag: View {
    let tag: PerpsAssetChartTag

    var body: some View {
        PerpsAssetCrosshairTagColumn(
            tag: tag,
            sizingLabels: [TKLocales.Perps.Chart.volume, TKLocales.Perps.Chart.high, TKLocales.Perps.Chart.low]
        )
    }
}

private struct PerpsAssetCrosshairTagColumn: View {
    let tag: PerpsAssetChartTag
    let sizingLabels: [String]

    var body: some View {
        ZStack {
            ForEach(sizingLabels, id: \.self) { label in
                PerpsAssetChartTag(text: label).hidden()
            }
            tag
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct PerpsAssetInfoSection: View {
    let ready: PerpsAssetPageReady

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Perps.Asset.info))
                .padding(.horizontal, Layout.listInset)
            VStack(spacing: 0) {
                PerpsAssetInfoRow(
                    label: TKLocales.Perps.Asset.volume24h,
                    value: ready.volumeText,
                    hint: TKLocales.Perps.Asset.Volume24h.hint
                )
                PerpsAssetSeparator(inset: Layout.cellPadding)
                PerpsAssetInfoRow(
                    label: TKLocales.Perps.openInterest,
                    value: ready.openInterestText,
                    hint: TKLocales.Perps.Asset.OpenInterest.hint
                )
                if let funding = ready.fundingText {
                    PerpsAssetSeparator(inset: Layout.cellPadding)
                    PerpsAssetInfoRow(
                        label: TKLocales.Perps.Asset.funding,
                        value: funding,
                        hint: TKLocales.Perps.Asset.FundingRate.hint
                    )
                }
            }
            .asCellsGroup()
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }
}

private struct PerpsAssetInfoRow: View {
    let label: String
    let value: String
    var hint: String?

    var body: some View {
        HStack(spacing: 0) {
            if let hint {
                PerpsAssetInfoLabel(label, hint: hint)
            } else {
                Text(label)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Layout.rowGap)
            Text(value)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Layout.cellPadding)
        .padding(.vertical, Layout.cellLabelVerticalPadding)
    }
}

private struct PerpsAssetInfoLabel: View {
    let label: String
    let hint: String

    init(_ label: String, hint: String) {
        self.label = label
        self.hint = hint
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
            HintButton(
                configuration: HintConfiguration(
                    position: HintPosition(
                        tailParameters: TKHintTextView.tailParameters,
                        horizontal: .default,
                        vertical: .init(absolute: 1),
                        direction: .bottomLeft
                    ),
                    animationStyle: .bouncing
                )
            ) { position in
                TKHintTextView(text: hint, position: position)
            } label: {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.informationCircle)
                    .renderingMode(.template)
                    .foregroundStyle(.iconTertiary)
            }
            .padding(.leading, Layout.infoIconSpacing)
        }
    }
}

private struct PerpsAssetAboutSection: View {
    let about: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Perps.Asset.about))
                .padding(.horizontal, Layout.listInset)
            TKExpandableTextView(
                text: about,
                collapsedLineLimit: Layout.aboutCollapsedLines,
                moreTitle: TKLocales.Actions.more,
                lessTitle: TKLocales.Perps.Asset.less,
                style: .init(contentInsets: EdgeInsets(
                    top: Layout.cellCaptionVerticalPadding,
                    leading: Layout.cellPadding,
                    bottom: Layout.cellCaptionVerticalPadding,
                    trailing: Layout.cellPadding
                ))
            )
            .padding(.horizontal, Layout.listInset)
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }
}

private struct PerpsAssetRiskDisclosureFootnote: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.infoIconSpacing) {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.informationCircle)
                    .renderingMode(.template)
                    .foregroundStyle(.iconSecondary)
                Text(TKLocales.Perps.RiskDisclosure.footnote)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.listInset)
            .padding(.bottom, Layout.sectionBottomPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("perps_risk_disclosure")
    }
}

private struct PerpsAssetPositionSection: View {
    let position: PerpsAssetPagePosition
    let autoClose: PerpsAssetPageAutoCloseAffordance
    let canAdjustMargin: Bool
    let canEditAutoClose: Bool
    @Binding var showSizeInToken: Bool
    let onShare: () -> Void
    let onAdjustMargin: () -> Void
    let onAutoClose: () -> Void

    private var showsSetAutoClose: Bool {
        canEditAutoClose && autoClose == .setAutoClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(TKLocales.Perps.Asset.yourPosition)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                Spacer()
                PerpsAssetShareButton(action: onShare)
            }
            .padding(.horizontal, Layout.listInset)
            .padding(.vertical, Layout.sectionTitleVerticalPadding)

            PerpsAssetPnlCard(position: position)
                .padding(.bottom, Layout.positionCardSpacing)
            PerpsAssetPositionDetailsCard(position: position, showSizeInToken: $showSizeInToken)
            if canAdjustMargin || showsSetAutoClose {
                PerpsAssetPositionManageCard(
                    showsAdjustMargin: canAdjustMargin,
                    showsSetAutoClose: showsSetAutoClose,
                    onAdjustMargin: onAdjustMargin,
                    onAutoClose: onAutoClose
                )
                .padding(.top, Layout.positionCardSpacing)
            }
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }
}

private struct PerpsAssetShareButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.badgeIconSpacing) {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.shareArrow)
                    .renderingMode(.template)
                Text(TKLocales.Perps.Asset.share)
                    .textStyle(.label2)
            }
            .foregroundStyle(.textAccent)
        }
    }
}

private struct PerpsAssetPnlCard: View {
    let position: PerpsAssetPagePosition

    var body: some View {
        let pnlColor: TKColor = position.isPnlPositive.map { $0 ? .accentGreen : .accentRed } ?? .textSecondary
        VStack(alignment: .leading, spacing: Layout.priceDeltaSpacing) {
            HStack(alignment: .top) {
                Text(position.valueText)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                Spacer()
                HStack(spacing: 0) {
                    if let leverage = position.leverageText {
                        TKTagSwiftUIView(config: .tag(text: leverage))
                    }
                    TKTagSwiftUIView(config: .accentTag(
                        text: position.sideText,
                        accent: position.isLong ? .accentGreen : .accentRed
                    ))
                }
            }
            if position.isPending {
                Text(TKLocales.Perps.Asset.pending)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
            } else {
                HStack(spacing: Layout.deltaSpacing) {
                    Text(position.pnlText)
                        .textStyle(.body2)
                        .foregroundStyle(pnlColor)
                    if let percent = position.pnlPercentText {
                        Text(percent)
                            .textStyle(.body2)
                            .foregroundStyle(pnlColor)
                            .opacity(Layout.deltaAmountOpacity)
                    }
                }
            }
        }
        .padding(.horizontal, Layout.cellPadding)
        .padding(.vertical, Layout.cellCaptionVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .asCellsGroup()
    }
}

private struct PerpsAssetPositionDetailsCard: View {
    let position: PerpsAssetPagePosition
    @Binding var showSizeInToken: Bool

    var body: some View {
        VStack(spacing: 0) {
            PerpsAssetSizeRow(position: position, showSizeInToken: $showSizeInToken)
            PerpsAssetSeparator(inset: Layout.cellPadding)
            PerpsAssetPositionRow(
                label: TKLocales.Perps.Asset.liquidationPrice,
                hint: TKLocales.Perps.Asset.LiquidationPrice.hint,
                value: position.liquidationText,
                subtitle: position.liquidationDistanceText
            )
            PerpsAssetSeparator(inset: Layout.cellPadding)
            PerpsAssetPositionRow(
                label: TKLocales.Perps.Asset.markPrice,
                hint: TKLocales.Perps.Asset.MarkPrice.hint,
                value: position.markText
            )
            PerpsAssetSeparator(inset: Layout.cellPadding)
            PerpsAssetPositionRow(
                label: TKLocales.Perps.Asset.entryPrice,
                hint: TKLocales.Perps.Asset.EntryPrice.hint,
                value: position.entryText
            )
            PerpsAssetSeparator(inset: Layout.cellPadding)
            PerpsAssetPositionRow(
                label: TKLocales.Perps.Asset.funding,
                hint: TKLocales.Perps.Asset.FundingRate.hint,
                value: position.fundingText
            )
        }
        .asCellsGroup()
    }
}

private struct PerpsAssetSizeRow: View {
    let position: PerpsAssetPagePosition
    @Binding var showSizeInToken: Bool

    var body: some View {
        HStack(spacing: 0) {
            PerpsAssetInfoLabel(TKLocales.Perps.Asset.size, hint: TKLocales.Perps.Asset.Size.hint)
            Button(action: { showSizeInToken.toggle() }) {
                HStack(spacing: 0) {
                    Spacer(minLength: Layout.rowGap)
                    Text(showSizeInToken ? position.sizeTokenText : position.sizeUsdText)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                        .multilineTextAlignment(.trailing)
                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.swap)
                        .renderingMode(.template)
                        .foregroundStyle(.iconTertiary)
                        .padding(.leading, Layout.rowGap)
                }
                .padding(.trailing, Layout.cellPadding)
                .padding(.vertical, Layout.cellLabelVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, Layout.cellPadding)
    }
}

private struct PerpsAssetPositionRow: View {
    let label: String
    let hint: String
    let value: String
    let subtitle: String?

    init(label: String, hint: String, value: String, subtitle: String? = nil) {
        self.label = label
        self.hint = hint
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: Layout.cellRowSpacing) {
                PerpsAssetInfoLabel(label, hint: hint)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.body3)
                        .foregroundStyle(.textTertiary)
                }
            }
            Spacer(minLength: Layout.rowGap)
            Text(value)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Layout.cellPadding)
        .padding(.top, Layout.cellLabelVerticalPadding)
        .padding(.bottom, subtitle == nil ? Layout.cellLabelVerticalPadding : Layout.cellCaptionVerticalPadding)
    }
}

private struct PerpsAssetPositionManageCard: View {
    let showsAdjustMargin: Bool
    let showsSetAutoClose: Bool
    let onAdjustMargin: () -> Void
    let onAutoClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if showsAdjustMargin {
                PerpsAssetAccentRow(title: TKLocales.Perps.Asset.adjustMargin, action: onAdjustMargin)
            }
            if showsSetAutoClose {
                if showsAdjustMargin {
                    PerpsAssetSeparator(inset: Layout.cellPadding)
                }
                PerpsAssetAccentRow(title: TKLocales.Perps.Asset.setAutoClose, action: onAutoClose)
            }
        }
        .asCellsGroup()
    }
}

private struct PerpsAssetAccentRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .textStyle(.label1)
                    .foregroundStyle(.textAccent)
                Spacer()
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                    .renderingMode(.template)
                    .foregroundStyle(.iconTertiary)
            }
            .padding(.horizontal, Layout.cellPadding)
            .padding(.vertical, Layout.cellLabelVerticalPadding)
            .contentShape(Rectangle())
        }
    }
}

struct PerpsAssetLimitOrdersSection: View {
    let orders: [PerpsAssetPageLimitOrder]
    let isEnabled: Bool
    let isBusy: Bool
    let onLimitOrder: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.positionCardSpacing) {
            ListTitleView(config: .text(TKLocales.Perps.Asset.limitOrders))
                .padding(.horizontal, Layout.listInset)
            ForEach(orders) { order in
                Button(action: { onLimitOrder(order.orderIndex) }) {
                    PerpsAssetLimitOrderCard(order: order, isBusy: isBusy)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                PerpsAssetLimitOrderAutoCloseCard(order: order)
            }
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }
}

private struct PerpsAssetLimitOrderAutoCloseCard: View {
    let order: PerpsAssetPageLimitOrder

    var body: some View {
        if order.takeProfitText != nil || order.stopLossText != nil {
            VStack(spacing: 0) {
                if let takeProfit = order.takeProfitText {
                    PerpsAssetInfoRow(label: TKLocales.Perps.Asset.takeProfit, value: takeProfit)
                }
                if order.takeProfitText != nil, order.stopLossText != nil {
                    PerpsAssetSeparator(inset: Layout.cellPadding)
                }
                if let stopLoss = order.stopLossText {
                    PerpsAssetInfoRow(label: TKLocales.Perps.Asset.stopLoss, value: stopLoss)
                }
            }
            .asCellsGroup()
        }
    }
}

private struct PerpsAssetLimitOrderCard: View {
    let order: PerpsAssetPageLimitOrder
    let isBusy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.priceDeltaSpacing) {
            HStack(alignment: .top) {
                Text(order.limitPriceText)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                Spacer()
                TKTagSwiftUIView(config: .accentTag(
                    text: order.sideText,
                    accent: order.isLong ? .accentGreen : .accentRed
                ))
            }
            Text(order.captionText)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
        }
        .tkTextShimmer(isActive: isBusy)
        .padding(.horizontal, Layout.cellPadding)
        .padding(.vertical, Layout.cellCaptionVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .asCellsGroup()
    }
}

private struct PerpsAssetOrdersSection: View {
    let triggerOrders: [PerpsAssetPageTriggerOrder]
    let autoClose: PerpsAssetPageAutoCloseAffordance
    let canEditAutoClose: Bool
    let onAutoClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Perps.Asset.orders))
                .padding(.horizontal, Layout.listInset)
            VStack(spacing: 0) {
                ForEach(Array(triggerOrders.enumerated()), id: \.element.id) { index, order in
                    if index > 0 {
                        PerpsAssetSeparator(inset: Layout.cellPadding)
                    }
                    PerpsAssetOrderRow(order: order, isEnabled: canEditAutoClose, action: onAutoClose)
                }
                if let setTitle {
                    PerpsAssetSeparator(inset: Layout.cellPadding)
                    PerpsAssetAccentRow(title: setTitle, action: onAutoClose)
                }
            }
            .asCellsGroup()
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }

    private var setTitle: String? {
        guard canEditAutoClose else { return nil }
        switch autoClose {
        case .setTakeProfit: return TKLocales.Perps.Asset.setTakeProfit
        case .setStopLoss: return TKLocales.Perps.Asset.setStopLoss
        case .setAutoClose, .none: return nil
        }
    }
}

private struct PerpsAssetOrderRow: View {
    let order: PerpsAssetPageTriggerOrder
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: Layout.tagRowSpacing) {
                    HStack(spacing: 0) {
                        Text(order.actionText)
                            .textStyle(.body1)
                            .foregroundStyle(.textPrimary)
                        TKTagSwiftUIView(config: .accentTag(
                            text: order.kindText,
                            accent: order.isTakeProfit ? .accentGreen : .accentRed
                        ))
                    }
                    Text("\(TKLocales.Perps.Order.price) \(order.priceText)")
                        .textStyle(.body3)
                        .foregroundStyle(.textSecondary)
                }
                Spacer(minLength: Layout.rowGap)
                if let value = order.valueText {
                    VStack(alignment: .trailing, spacing: Layout.cellRowSpacing) {
                        Text(value)
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)
                        if let percent = order.percentText {
                            Text(percent)
                                .textStyle(.body3)
                                .foregroundStyle(order.isPositive.map { $0 ? TKColor.accentGreen : TKColor.accentRed } ?? .textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.cellPadding)
            .padding(.top, Layout.cellLabelVerticalPadding)
            .padding(.bottom, Layout.cellCaptionVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct PerpsAssetHistorySection: View {
    let history: [PerpsAssetPageActivityRow]
    let onSeeAll: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(
                TKLocales.Perps.Asset.transactionHistory,
                accessory: .init(title: TKLocales.Perps.Asset.seeAll, action: onSeeAll)
            ))
            .padding(.horizontal, Layout.listInset)

            VStack(spacing: 0) {
                ForEach(Array(history.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        PerpsAssetSeparator(inset: Layout.cellPadding)
                    }
                    Button { onSelect(row.id) } label: {
                        PerpsAssetHistoryRow(row: row)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .asCellsGroup()
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }
}

private struct PerpsAssetHistoryRow: View {
    let row: PerpsAssetPageActivityRow

    var body: some View {
        HStack(spacing: 0) {
            SwiftUI.Image(uiImage: row.icon)
                .renderingMode(.template)
                .foregroundStyle(.iconSecondary)
                .frame(width: Layout.historyIconSide, height: Layout.historyIconSide)
                .background(Circle().fill(.backgroundContentTint))
                .padding(.trailing, Layout.cellPadding)
            VStack(alignment: .leading, spacing: Layout.cellRowSpacing) {
                Text(row.title)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                Text(row.subtitle)
                    .textStyle(.body3)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Layout.rowGap)
            VStack(alignment: .trailing, spacing: Layout.cellRowSpacing) {
                if let amount = row.amountText {
                    Text(amount)
                        .textStyle(.label1)
                        .foregroundStyle(row.amountStyle.color)
                }
                Text(row.dateText)
                    .textStyle(.body3)
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(.horizontal, Layout.cellPadding)
        .padding(.top, Layout.cellLabelVerticalPadding)
        .padding(.bottom, Layout.cellCaptionVerticalPadding)
    }
}

private extension PerpsAssetPageActivityRow.AmountStyle {
    var color: TKColor {
        switch self {
        case .primary: .textPrimary
        case .positive: .accentGreen
        case .negative: .accentRed
        }
    }
}

struct PerpsAssetStickyActions: View {
    let actions: PerpsAssetPageActions
    let isLimitOrderBusy: Bool
    let onLong: () -> Void
    let onShort: () -> Void
    let onEdit: () -> Void
    let onCashOut: () -> Void
    let onEditLimitOrder: (Int64) -> Void
    let onCancelLimitOrder: (Int64) -> Void

    var body: some View {
        let (leading, trailing) = buttons
        VStack {
            Spacer()
            HStack(spacing: Layout.actionSpacing) {
                leading
                trailing
            }
            .padding(Layout.cellPadding)
            .tkScrim(.backgroundPage, edge: .bottom)
        }
        .animation(.easeInOut(duration: 0.2), value: actions)
    }

    private var buttons: (PerpsAssetStickyButton, PerpsAssetStickyButton) {
        switch actions {
        case let .longShort(enabled):
            (
                PerpsAssetStickyButton(title: TKLocales.Perps.Asset.long, appearance: .primary, isEnabled: enabled, action: onLong),
                PerpsAssetStickyButton(title: TKLocales.Perps.Asset.short, appearance: .primary, isEnabled: enabled, action: onShort)
            )
        case let .editCashOut(editEnabled, cashOutEnabled):
            (
                PerpsAssetStickyButton(title: TKLocales.Perps.Asset.edit, appearance: .tertiary, isEnabled: editEnabled, action: onEdit),
                PerpsAssetStickyButton(title: TKLocales.Perps.Asset.cashOut, appearance: .primary, isEnabled: cashOutEnabled, action: onCashOut)
            )
        case let .editCancelLimitOrder(orderIndex, editEnabled, cancelEnabled):
            (
                PerpsAssetStickyButton(title: TKLocales.Perps.Asset.edit, appearance: .tertiary, isEnabled: editEnabled, isBusy: isLimitOrderBusy) {
                    onEditLimitOrder(orderIndex)
                },
                PerpsAssetStickyButton(title: TKLocales.Actions.cancel, appearance: .primary, isEnabled: cancelEnabled, isBusy: isLimitOrderBusy) {
                    onCancelLimitOrder(orderIndex)
                }
            )
        }
    }
}

private struct PerpsAssetStickyButton: View {
    let title: String
    let appearance: ButtonView.Appearance
    let isEnabled: Bool
    var isBusy = false
    let action: () -> Void

    var body: some View {
        ButtonView(config: .init(
            title: title,
            size: .large,
            layoutMode: .fill,
            appearance: appearance,
            showsTextShimmer: isBusy,
            action: action
        ))
        .disabled(!isEnabled)
    }
}

private struct PerpsAssetSeparator: View {
    let inset: CGFloat

    init(inset: CGFloat = 0) {
        self.inset = inset
    }

    var body: some View {
        Rectangle()
            .fill(.separatorCommon)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.separatorHeight)
            .padding(.leading, inset)
    }
}

private enum Layout {
    static let cardCornerRadius: CGFloat = 16
    static let listInset: CGFloat = 16
    static let cellPadding: CGFloat = 16
    static let historyIconSide: CGFloat = 44
    static let cellLabelVerticalPadding: CGFloat = 14
    static let cellCaptionVerticalPadding: CGFloat = 15
    static let cellRowSpacing: CGFloat = 1
    static let separatorHeight: CGFloat = 0.5
    static let rowGap: CGFloat = 8
    static let bottomPadding: CGFloat = 16
    static let failedSpacing: CGFloat = 14
    static let sectionBottomPadding: CGFloat = 16
    static let sectionTitleVerticalPadding: CGFloat = 10

    static let headerHeight: CGFloat = 64
    static let headerSide: CGFloat = 8
    static let headerButtonSide: CGFloat = 32
    static let headerTitleInset: CGFloat = 64
    static let badgeIconSpacing: CGFloat = 4

    static let marketTopPadding: CGFloat = 16
    static let marketBottomPadding: CGFloat = 5
    static let marketHorizontalPadding: CGFloat = 24
    static let marketIconSpacing: CGFloat = 11
    static let priceDeltaSpacing: CGFloat = 1
    static let deltaSpacing: CGFloat = 8
    static let deltaAmountOpacity: Double = 0.48
    static let iconSide: CGFloat = 56
    static let marketContentHeight: CGFloat = 72
    static let skeletonLineSpacing: CGFloat = 8
    static let tagRowSpacing: CGFloat = 3
    static let readoutRowSpacing: CGFloat = 4
    static let crosshairValueSpacing: CGFloat = 6
    static let chipTintOpacity: CGFloat = 0.16
    static let chartTagTextPadding = UIEdgeInsets(top: 0.5, left: 4, bottom: 1.5, right: 4)

    static let infoIconSpacing: CGFloat = 4

    static let aboutCollapsedLines = 3

    static let positionCardSpacing: CGFloat = 8

    static let bannerHeight: CGFloat = 90

    static let actionSpacing: CGFloat = 12
    static let actionBarHeight: CGFloat = 88
}
