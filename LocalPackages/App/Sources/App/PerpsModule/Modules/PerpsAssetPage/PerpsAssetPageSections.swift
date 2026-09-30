import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsAssetPageHeader: View {
    let title: String
    let onBack: () -> Void
    let onPerpetualInfo: () -> Void
    let onMore: () -> Void

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
                Spacer()
                PerpsAssetHeaderButton(icon: .TKUIKit.Icons.Size16.ellipses, action: onMore)
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
    let toast: PerpsAssetPageViewModel.TradeToast

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
        case .failure:
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.exclamationMarkCircle)
                .renderingMode(.template)
                .foregroundStyle(.accentRed)
        }
    }

    private var text: String {
        switch toast {
        case let .progress(text), let .success(text), let .failure(text): text
        }
    }
}

struct PerpsAssetLoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            CircularLoader(mode: .indeterminate, preset: .medium)
            Spacer()
        }
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

struct PerpsAssetPageReadyView: View {
    let ready: PerpsAssetPageViewModel.Ready
    @ObservedObject var chartViewModel: PerpsChartViewModel
    let chartMarkers: [PerpsChartPositionMarker]
    let safeAreaBottom: CGFloat
    @Binding var showSizeInToken: Bool
    let onShare: () -> Void
    let onAdjustMargin: () -> Void
    let onAutoClose: () -> Void
    let onLimitOrder: (Int64) -> Void
    let onSeeAllHistory: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PerpsAssetMarketSection(ready: ready, chartViewModel: chartViewModel)
                PerpsChartView(viewModel: chartViewModel, markers: chartMarkers)
                PerpsAssetSeparator()
                positionAndOrders
                if !ready.history.isEmpty {
                    PerpsAssetHistorySection(history: ready.history, onSeeAll: onSeeAllHistory)
                }
                PerpsAssetInfoSection(ready: ready)
                if let about = ready.about {
                    PerpsAssetAboutSection(about: about)
                }
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
        if !ready.limitOrders.isEmpty || !ready.orders.isEmpty {
            PerpsAssetOrdersSection(
                limitOrders: ready.limitOrders,
                triggerOrders: ready.orders,
                autoClose: ready.autoClose,
                canEditAutoClose: ready.canEditAutoClose,
                canCancelOrders: ready.canCancelOrders,
                onAutoClose: onAutoClose,
                onLimitOrder: onLimitOrder
            )
        }
    }
}

private struct PerpsAssetMarketSection: View {
    let ready: PerpsAssetPageViewModel.Ready
    @ObservedObject var chartViewModel: PerpsChartViewModel

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
        if let candle = chartViewModel.selectedCandle {
            switch chartViewModel.mode {
            case .candle:
                PerpsAssetCandleCrosshairReadout(
                    candle: candle,
                    selectedChange: chartViewModel.selectedChange
                )
            case .line:
                PerpsAssetLineCrosshairReadout(
                    candle: candle,
                    selectedChange: chartViewModel.selectedChange
                )
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
    let isPositive: Bool
    let trailing: String?

    init(price: String, percent: String, amount: String, isPositive: Bool, trailing: String? = nil) {
        self.price = price
        self.percent = percent
        self.amount = amount
        self.isPositive = isPositive
        self.trailing = trailing
    }

    var body: some View {
        let changeColor: TKColor = isPositive ? .accentGreen : .accentRed
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
                if let trailing {
                    Text(trailing)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
            }
        }
    }
}

private struct PerpsAssetLineCrosshairReadout: View {
    let candle: PerpsChartCandle
    let selectedChange: PerpsChartViewModel.SelectedChange?

    var body: some View {
        PerpsAssetPriceChangeBlock(
            price: PerpsFormatting.usd(candle.close),
            percent: PerpsFormatting.signedPercent(selectedChange?.percent ?? 0),
            amount: PerpsFormatting.signedUsd(selectedChange?.amount ?? 0),
            isPositive: selectedChange?.isPositive ?? true,
            trailing: PerpsFormatting.candleDateTime(candle.openedAt)
        )
    }
}

private struct PerpsAssetCandleCrosshairReadout: View {
    let candle: PerpsChartCandle
    let selectedChange: PerpsChartViewModel.SelectedChange?

    var body: some View {
        let isClosePositive = selectedChange?.isPositive ?? true
        let closeColor: TKColor = isClosePositive ? .accentGreen : .accentRed
        HStack(alignment: .top, spacing: Layout.rowGap) {
            VStack(alignment: .leading, spacing: Layout.tagRowSpacing) {
                Text(PerpsFormatting.candleDateTime(candle.openedAt))
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                PerpsAssetCrosshairLeadingCell(
                    tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.open),
                    value: PerpsFormatting.usd(candle.open)
                )
                HStack(spacing: Layout.crosshairValueSpacing) {
                    PerpsAssetCrosshairLeadingTag(
                        tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.close, color: closeColor)
                    )
                    Text(PerpsFormatting.usd(candle.close))
                        .textStyle(.body2)
                        .foregroundStyle(.textPrimary)
                    Text(PerpsFormatting.signedPercent(selectedChange?.percent ?? 0))
                        .textStyle(.body2)
                        .foregroundStyle(closeColor)
                }
            }
            Spacer(minLength: Layout.rowGap)
            VStack(alignment: .trailing, spacing: Layout.tagRowSpacing) {
                PerpsAssetCrosshairTrailingCell(
                    value: candle.volume.map(PerpsFormatting.usd) ?? "—",
                    tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.volume)
                )
                PerpsAssetCrosshairTrailingCell(
                    value: PerpsFormatting.usd(candle.high),
                    tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.high)
                )
                PerpsAssetCrosshairTrailingCell(
                    value: PerpsFormatting.usd(candle.low),
                    tag: PerpsAssetChartTag(text: TKLocales.Perps.Chart.low)
                )
            }
        }
    }
}

private struct PerpsAssetChartTag: View {
    let text: String
    let color: TKColor?

    init(text: String, color: TKColor? = nil) {
        self.text = text
        self.color = color
    }

    var body: some View {
        TKTagSwiftUIView(config: .init(
            text: text,
            style: style,
            backgroundPadding: .zero
        ))
    }

    private var style: TKTagSwiftUIViewConfig.Style {
        if let color {
            .custom(
                textColor: color,
                backgroundColor: color.opacity(Layout.chipTintOpacity),
                borderColor: .clear
            )
        } else {
            .plain
        }
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
            sizingLabels: [TKLocales.Perps.Chart.open, TKLocales.Perps.Chart.close],
            alignment: .trailing
        )
    }
}

private struct PerpsAssetCrosshairTrailingTag: View {
    let tag: PerpsAssetChartTag

    var body: some View {
        PerpsAssetCrosshairTagColumn(
            tag: tag,
            sizingLabels: [TKLocales.Perps.Chart.volume, TKLocales.Perps.Chart.high, TKLocales.Perps.Chart.low],
            alignment: .leading
        )
    }
}

private struct PerpsAssetCrosshairTagColumn: View {
    let tag: PerpsAssetChartTag
    let sizingLabels: [String]
    let alignment: Alignment

    var body: some View {
        ZStack(alignment: alignment) {
            ForEach(sizingLabels, id: \.self) { label in
                PerpsAssetChartTag(text: label).hidden()
            }
            tag
        }
    }
}

private struct PerpsAssetInfoSection: View {
    let ready: PerpsAssetPageViewModel.Ready

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Perps.Asset.info))
                .padding(.horizontal, Layout.listInset)
            VStack(spacing: 0) {
                PerpsAssetInfoRow(label: TKLocales.Perps.Asset.volume24h, value: ready.volumeText)
                PerpsAssetSeparator(inset: Layout.cellPadding)
                PerpsAssetInfoRow(label: TKLocales.Perps.openInterest, value: ready.openInterestText)
                if let funding = ready.fundingText {
                    PerpsAssetSeparator(inset: Layout.cellPadding)
                    PerpsAssetInfoRow(label: TKLocales.Perps.Asset.funding, value: funding)
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

    var body: some View {
        HStack(spacing: 0) {
            PerpsAssetInfoLabel(label)
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

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.informationCircle)
                .renderingMode(.template)
                .foregroundStyle(.iconTertiary)
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

private struct PerpsAssetPositionSection: View {
    let position: PerpsAssetPageViewModel.Position
    let autoClose: PerpsAssetPageViewModel.AutoCloseAffordance
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
    let position: PerpsAssetPageViewModel.Position

    var body: some View {
        let pnlColor: TKColor = position.isPnlPositive ? .accentGreen : .accentRed
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
        .padding(.horizontal, Layout.cellPadding)
        .padding(.vertical, Layout.cellCaptionVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .asCellsGroup()
    }
}

private struct PerpsAssetPositionDetailsCard: View {
    let position: PerpsAssetPageViewModel.Position
    @Binding var showSizeInToken: Bool

    var body: some View {
        VStack(spacing: 0) {
            PerpsAssetSizeRow(position: position, showSizeInToken: $showSizeInToken)
            PerpsAssetSeparator(inset: Layout.cellPadding)
            PerpsAssetPositionRow(
                label: TKLocales.Perps.Asset.liquidationPrice,
                value: position.liquidationText,
                subtitle: position.liquidationDistanceText
            )
            PerpsAssetSeparator(inset: Layout.cellPadding)
            PerpsAssetPositionRow(label: TKLocales.Perps.Asset.markPrice, value: position.markText)
            PerpsAssetSeparator(inset: Layout.cellPadding)
            PerpsAssetPositionRow(label: TKLocales.Perps.Asset.entryPrice, value: position.entryText)
            PerpsAssetSeparator(inset: Layout.cellPadding)
            PerpsAssetPositionRow(label: TKLocales.Perps.Asset.funding, value: position.fundingText)
        }
        .asCellsGroup()
    }
}

private struct PerpsAssetSizeRow: View {
    let position: PerpsAssetPageViewModel.Position
    @Binding var showSizeInToken: Bool

    var body: some View {
        Button(action: { showSizeInToken.toggle() }) {
            HStack(spacing: 0) {
                PerpsAssetInfoLabel(TKLocales.Perps.Asset.size)
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
            .padding(.horizontal, Layout.cellPadding)
            .padding(.vertical, Layout.cellLabelVerticalPadding)
        }
        .buttonStyle(.plain)
    }
}

private struct PerpsAssetPositionRow: View {
    let label: String
    let value: String
    let subtitle: String?

    init(label: String, value: String, subtitle: String? = nil) {
        self.label = label
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: Layout.cellRowSpacing) {
                PerpsAssetInfoLabel(label)
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
        }
    }
}

private struct PerpsAssetOrdersSection: View {
    let limitOrders: [PerpsAssetPageViewModel.LimitOrder]
    let triggerOrders: [PerpsAssetPageViewModel.TriggerOrder]
    let autoClose: PerpsAssetPageViewModel.AutoCloseAffordance
    let canEditAutoClose: Bool
    let canCancelOrders: Bool
    let onAutoClose: () -> Void
    let onLimitOrder: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Perps.Asset.orders))
                .padding(.horizontal, Layout.listInset)
            VStack(spacing: 0) {
                ForEach(Array(limitOrders.enumerated()), id: \.element.id) { index, order in
                    if index > 0 {
                        PerpsAssetSeparator(inset: Layout.cellPadding)
                    }
                    PerpsAssetLimitOrderRow(order: order, isEnabled: canCancelOrders) {
                        onLimitOrder(order.orderIndex)
                    }
                }
                ForEach(Array(triggerOrders.enumerated()), id: \.element.id) { index, order in
                    if index > 0 || !limitOrders.isEmpty {
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

private struct PerpsAssetLimitOrderRow: View {
    let order: PerpsAssetPageViewModel.LimitOrder
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
                            text: TKLocales.Perps.OrderType.limit,
                            accent: .accentBlue
                        ))
                    }
                    Text("\(TKLocales.Perps.OpenPosition.price) \(order.priceText)")
                        .textStyle(.body3)
                        .foregroundStyle(.textSecondary)
                }
                Spacer(minLength: Layout.rowGap)
                Text(order.valueText)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
            }
            .padding(.horizontal, Layout.cellPadding)
            .padding(.top, Layout.cellLabelVerticalPadding)
            .padding(.bottom, Layout.cellCaptionVerticalPadding)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct PerpsAssetOrderRow: View {
    let order: PerpsAssetPageViewModel.TriggerOrder
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
                    Text("\(TKLocales.Perps.OpenPosition.price) \(order.priceText)")
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
                                .foregroundStyle(order.isPositive ? .accentGreen : .accentRed)
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.cellPadding)
            .padding(.top, Layout.cellLabelVerticalPadding)
            .padding(.bottom, Layout.cellCaptionVerticalPadding)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct PerpsAssetHistorySection: View {
    let history: [PerpsAssetPageViewModel.ActivityRow]
    let onSeeAll: () -> Void

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
                    PerpsAssetHistoryRow(row: row)
                }
            }
            .asCellsGroup()
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }
}

private struct PerpsAssetHistoryRow: View {
    let row: PerpsAssetPageViewModel.ActivityRow

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Layout.cellRowSpacing) {
                Text(row.title)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                Text(row.symbol)
                    .textStyle(.body3)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Layout.rowGap)
            VStack(alignment: .trailing, spacing: Layout.cellRowSpacing) {
                if let amount = row.amountText {
                    Text(amount)
                        .textStyle(.label1)
                        .foregroundStyle(row.isAmountPositive ? .accentGreen : .accentRed)
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

struct PerpsAssetStickyActions: View {
    let actions: PerpsAssetPageViewModel.Actions
    let onLong: () -> Void
    let onShort: () -> Void
    let onEdit: () -> Void
    let onCashOut: () -> Void

    var body: some View {
        switch actions {
        case .hidden:
            EmptyView()
        case let .longShort(enabled):
            stickyBar {
                PerpsAssetStickyButton(title: TKLocales.Perps.Asset.long, appearance: .primary, isEnabled: enabled, action: onLong)
                PerpsAssetStickyButton(title: TKLocales.Perps.Asset.short, appearance: .primary, isEnabled: enabled, action: onShort)
            }
        case let .editCashOut(editEnabled, cashOutEnabled):
            stickyBar {
                PerpsAssetStickyButton(title: TKLocales.Perps.Asset.edit, appearance: .tertiary, isEnabled: editEnabled, action: onEdit)
                PerpsAssetStickyButton(title: TKLocales.Perps.Asset.cashOut, appearance: .primary, isEnabled: cashOutEnabled, action: onCashOut)
            }
        }
    }

    private func stickyBar(@ViewBuilder buttons: () -> some View) -> some View {
        VStack {
            Spacer()
            HStack(spacing: Layout.actionSpacing) {
                buttons()
            }
            .padding(Layout.cellPadding)
            .tkScrim(.backgroundPage, edge: .bottom)
        }
    }
}

private struct PerpsAssetStickyButton: View {
    let title: String
    let appearance: ButtonView.Appearance
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        ButtonView(config: .init(
            title: title,
            size: .large,
            layoutMode: .fill,
            appearance: appearance,
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
    static let tagRowSpacing: CGFloat = 3
    static let crosshairValueSpacing: CGFloat = 6
    static let chipTintOpacity: CGFloat = 0.16

    static let infoIconSpacing: CGFloat = 4

    static let aboutCollapsedLines = 3

    static let positionCardSpacing: CGFloat = 8

    static let actionSpacing: CGFloat = 12
    static let actionBarHeight: CGFloat = 88
}
