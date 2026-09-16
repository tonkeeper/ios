import AppUI
import SwiftUI
import TKLocalize
import TKUIKit

struct TradeAssetDetailsView: View {
    @Environment(\.tkPalette) private var palette
    @ObservedObject var viewModel: TradeAssetDetailsViewModel

    enum Section {
        case chart(TokenChartViewState)
        case balance(TradeAssetDetailsBalanceSectionViewData?)
        case actions([TradeAssetDetailsActionButton])
        case tronFees(TradeAssetDetailsTronFeesViewData)
        case assetType(TradeAssetDetailsAssetTypeSectionKind)
        case history(TradeAssetDetailsHistorySectionViewData)
        case multichainHistory(TradeAssetDetailsMultichainHistorySectionViewData)
        case about(TradeAssetDetailsScreenViewData)
        case overview(TradeAssetDetailsScreenViewData)
        case tradingActivity(TradeAssetDetailsTradingActivityViewData)
        case links(TradeAssetDetailsScreenViewData)
    }

    var body: some View {
        ZStack {
            palette.background.page
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                contentView
            }
            .safeAreaInset(edge: .bottom) {
                if let screen = viewModel.screen, screen.actionBarState != .none {
                    TradeAssetDetailsActionBarView(
                        primaryActionTitle: screen.primaryActionTitle,
                        state: screen.actionBarState,
                        onBuy: viewModel.handleBuyAction,
                        onSell: viewModel.handleSellAction
                    )
                    .padding(.top, Layout.actionsBarTopPadding)
                }
            }
        }
        .tkBottomSheet(
            item: Binding(
                get: { viewModel.selectedMultichainActivity },
                set: { newValue in
                    if newValue == nil {
                        viewModel.dismissMultichainActivity()
                    }
                }
            ),
            header: { _, _ in .compact },
            content: { activity in
                MultichainTransactionDetailsView(
                    model: viewModel.multichainTransactionDetailsModel(for: activity),
                    onOpenTransaction: { url, _ in
                        viewModel.open(url: url)
                    },
                    onCopy: { Pasteboard.copy(value: $0) }
                )
            }
        )
    }
}

extension TradeAssetDetailsView {
    @ViewBuilder
    var contentView: some View {
        if let screen = viewModel.screen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    tokenAvatarView(shimmer: false)
                    let sections = self.sections(for: screen)
                    ForEach(0 ..< sections.count, id: \.self) { index in
                        let topPadding: CGFloat = switch sections[index] {
                        case .chart:
                            Layout.chartTopPadding
                        case .assetType:
                            0
                        case .balance:
                            switch sections[safe: index - 1] {
                            case .chart:
                                Layout.balanceUnderChartTopPadding
                            case .assetType:
                                Layout.balanceUnderAssetTypeTopPadding
                            default:
                                Layout.regularSectionTopSpacing
                            }
                        case .actions:
                            switch sections[safe: index - 1] {
                            case .balance:
                                Layout.actionsUnderBalanceTopPadding
                            default:
                                Layout.regularSectionTopSpacing
                            }
                        default:
                            Layout.regularSectionTopSpacing
                        }
                        sectionView(for: sections[index])
                            .padding(.top, topPadding)
                    }
                }
            }
            .tkImmediateButtonPresses()
            .refreshable {
                await Task {
                    await MinimumRefreshDurationBehavior.perform {
                        await viewModel.refresh()
                    }
                }.value
            }
        } else if viewModel.isLoading {
            VStack(spacing: 0) {
                tokenAvatarView(shimmer: true)
                let sections = self.shimmerSections
                ForEach(0 ..< sections.count, id: \.self) { index in
                    let topPadding: CGFloat = if index > 0, case .chart = sections[index - 1] {
                        Layout.nextSectionToChartTopSpacing
                    } else if case .chart = sections[index] {
                        Layout.chartTopPadding
                    } else {
                        Layout.regularSectionTopSpacing
                    }
                    sectionView(for: sections[index])
                        .padding(.top, topPadding)
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 0) {
                PlaceholderView(
                    config: PlaceholderView.Config(
                        lottieResource: .exclamationmarkCircle,
                        title: TKLocales.Trade.Placeholder.errorTitle,
                        subtitle: viewModel.errorMessage ?? TKLocales.Trade.Placeholder.errorSubtitle,
                        button: PlaceholderView.ButtonConfig(
                            title: TKLocales.Actions.retry,
                            icon: .TKUIKit.Icons.Size16.refresh,
                            action: {
                                Task {
                                    await viewModel.refresh()
                                }
                            }
                        )
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.top, Layout.placeholderTopPadding)

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    var headerView: some View {
        if let header = viewModel.header {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    leftIcon: DefaultModalCardHeader.Icon(
                        image: .TKUIKit.Icons.Size16.chevronLeft,
                        size: 16,
                        padding: 8,
                        accessibilityIdentifier: "trade_asset_details_back",
                        onTap: { _ in
                            viewModel.goBack()
                        }
                    ),
                    title: DefaultModalCardHeader.Title(
                        text: header.title,
                        trailingIcon: header.showsVerificationCheckmark ? DefaultModalCardHeader.TitleTrailingIcon(
                            image: .TKUIKit.Icons.Size16.verification,
                            tint: .accentBlue,
                            size: 16,
                            onTap: viewModel.handleOpenVerifiedTokenInfo
                        ) : nil
                    ),
                    subtitle: header.subtitle
                        .map { subtitle in
                            DefaultModalCardHeader.Subtitle(
                                text: subtitle.title,
                                color: subtitle.color,
                                icon: subtitle.hasInformationCircleIcon ? DefaultModalCardHeader.SubtitleIcon(
                                    image: .TKUIKit.Icons.Size12.informationCircle,
                                    size: 12,
                                    topPadding: 4
                                ) : nil,
                                onTap: {
                                    viewModel.onTapHeader(data: subtitle)
                                }
                            )
                        },
                    rightIcon: popupMenuItems.isEmpty ? nil : DefaultModalCardHeader.Icon(
                        image: .TKUIKit.Icons.Size16.ellipses,
                        size: 16,
                        padding: 8,
                        accessibilityIdentifier: "trade_asset_details_menu",
                        onTap: { anchor in
                            guard let anchor else {
                                return
                            }
                            TKPopupMenuController.show(
                                sourceView: anchor,
                                position: .bottomRight(inset: 8),
                                minimumWidth: 200,
                                items: popupMenuItems,
                                isSelectable: false,
                                selectedIndex: nil
                            )
                        }
                    ),
                    secondaryRightIcon: viewModel.isFavoritesEnabled ? DefaultModalCardHeader.Icon(
                        image: .TKUIKit.Icons.Size16.star,
                        size: 16,
                        padding: 8,
                        lottie: viewModel.isFavorite.map { isOn in
                            DefaultModalCardHeader.Lottie(
                                resource: .favorite,
                                isOn: isOn
                            )
                        },
                        onTap: { _ in
                            viewModel.toggleFavorite()
                        },
                        onResolveAnchorView: { view in
                            viewModel.setFavoriteTooltipAnchor(view)
                        }
                    ) : nil
                )
            )
        }
    }

    @ViewBuilder
    func tokenAvatarView(shimmer: Bool) -> some View {
        if let header = viewModel.header {
            HStack(alignment: .top, spacing: 0) {
                AssetAvatarView(
                    imageSource: shimmer
                        ? .shimmer
                        : header.imageSource,
                    size: .regular
                )

                Spacer(minLength: 0)

                if let earnText = header.earnText {
                    Button(action: viewModel.handleOpenEarnAction) {
                        HStack(spacing: 6) {
                            SwiftUI.Image.TKUIKit.Icons.Size16.staking
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.accentGreen)
                                .frame(width: 16, height: 16)
                                .padding(.leading, 12)
                            Text(earnText)
                                .textStyle(.label2)
                                .foregroundStyle(.accentGreen)
                                .padding(.trailing, 12)
                        }
                        .frame(height: 32)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.accentGreen.opacity(0.16))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, Layout.secondaryHorizontalPadding)
            .padding(.trailing, Layout.earnTrailingPadding)
            .padding(.top, Layout.secondaryTopPadding)
        }
    }

    var popupMenuItems: [TKPopupMenuItem] {
        let explorerItem = viewModel.explorerMenuItem
            .map { explorerItem in
                TKPopupMenuItem(
                    title: explorerItem.title,
                    icon: explorerItem.icon,
                    hasSeparator: viewModel.tokenVisibilityMenuItem != nil,
                    selectionHandler: viewModel.openAssetExplorer
                )
            }

        let visibilityItem = viewModel.tokenVisibilityMenuItem
            .map { visibilityItem in
                TKPopupMenuItem(
                    title: visibilityItem.title,
                    icon: visibilityItem.icon,
                    selectionHandler: viewModel.toggleAssetVisibility
                )
            }

        return [
            explorerItem,
            visibilityItem,
        ].compactMap { $0 }
    }

    @ViewBuilder
    func sectionView(for section: Section) -> some View {
        switch section {
        case let .chart(chartState):
            TokenChartView(state: chartState)
        case let .balance(balance):
            TradeAssetDetailsBalanceSectionView(
                balance: balance
            )
        case let .actions(buttons):
            AssetActionButtonsRow(items: actionItems(for: buttons))
                .padding(.horizontal, Layout.actionsHorizontalPadding)
        case let .tronFees(tronFees):
            TradeAssetDetailsTronFeesSectionView(
                data: tronFees,
                onTap: viewModel.handleTronFeesAction
            )
        case let .assetType(kind):
            TradeAssetDetailsAssetTypeSectionView(
                kind: kind
            ) {
                viewModel.onTapAssetType(assetKind: kind)
            }
        case let .history(history):
            TradeAssetDetailsHistorySectionView(
                screen: history,
                onSelectItem: { id in
                    viewModel.openHistoryEvent(id: id)
                },
                onSeeAll: viewModel.openHistory
            )
        case let .multichainHistory(history):
            TradeAssetDetailsMultichainHistorySectionView(
                screen: history,
                onSelectActivity: { activity in
                    viewModel.openMultichainHistoryEvent(activity: activity)
                },
                onSeeAll: viewModel.openHistory
            )
        case let .about(screen):
            TradeAssetDetailsAboutSectionView(
                screen: screen
            )
        case let .overview(screen):
            TradeAssetDetailsOverviewSectionView(
                screen: screen
            )
        case let .tradingActivity(tradingActivity):
            TradeAssetDetailsTradingActivitySectionView(
                tradingActivity: tradingActivity,
                onOpenURL: viewModel.open(url:)
            )
        case let .links(screen):
            TradeAssetDetailsLinksSectionView(
                screen: screen,
                onOpenURL: viewModel.open(url:)
            )
        }
    }

    func actionItems(for buttons: [TradeAssetDetailsActionButton]) -> [AssetActionButtonsRow.Item] {
        buttons.map { button in
            switch button {
            case .send:
                AssetActionButtonsRow.Item(
                    id: "trade_asset_details_send",
                    icon: .TKUIKit.Icons.Size16.linkSmall,
                    title: TKLocales.WalletButtons.send,
                    action: viewModel.handleSendAction
                )
            case .receive:
                AssetActionButtonsRow.Item(
                    id: "trade_asset_details_receive",
                    icon: .TKUIKit.Icons.Size16.qrCode,
                    title: TKLocales.WalletButtons.receive,
                    action: viewModel.handleReceiveAction
                )
            case .cashBuy:
                AssetActionButtonsRow.Item(
                    id: "trade_asset_details_cash_buy",
                    icon: .TKUIKit.Icons.Size16.dollarOutlinePlus,
                    title: TKLocales.Trade.AssetDetails.Actions.cashBuy,
                    action: viewModel.handleCashBuyAction
                )
            case .cashSell:
                AssetActionButtonsRow.Item(
                    id: "trade_asset_details_cash_sell",
                    icon: .TKUIKit.Icons.Size16.dollarOutlineMinus,
                    title: TKLocales.Trade.AssetDetails.Actions.cashSell,
                    action: viewModel.handleSellToCardAction
                )
            }
        }
    }

    var shimmerSections: [Section] {
        var sections: [Section] = []

        if let chartState = viewModel.chartState {
            sections.append(.chart(chartState))
        }
        sections.append(.balance(nil))

        return sections
    }

    func sections(for screen: TradeAssetDetailsScreenViewData) -> [Section] {
        var sections: [Section] = []

        if let chartState = viewModel.chartState {
            sections.append(.chart(chartState))
        }
        if let kind = screen.assetType {
            sections.append(.assetType(kind))
        }
        if let balance = screen.balance {
            sections.append(.balance(balance))
        }
        if !screen.actionButtons.isEmpty {
            sections.append(.actions(screen.actionButtons))
        }
        if let tronFees = screen.tronFees {
            sections.append(.tronFees(tronFees))
        }
        if let history = screen.history {
            sections.append(.history(history))
        }
        if let multichainHistory = screen.multichainHistory {
            sections.append(.multichainHistory(multichainHistory))
        }
        sections.append(.about(screen))
        if !screen.overview.isEmpty {
            sections.append(.overview(screen))
        }
        if let tradingActivity = screen.tradingActivity {
            sections.append(.tradingActivity(tradingActivity))
        }
        if !screen.links.isEmpty {
            sections.append(.links(screen))
        }
        return sections
    }
}

private extension TradeAssetDetailsView {
    enum Layout {
        static let chartTopPadding: CGFloat = 14
        static let nextSectionToChartTopSpacing: CGFloat = 3
        static let balanceUnderAssetTypeTopPadding: CGFloat = 4
        static let balanceUnderChartTopPadding: CGFloat = 3
        static let actionsUnderBalanceTopPadding: CGFloat = 8
        static let actionsHorizontalPadding: CGFloat = 16

        static let regularSectionTopSpacing: CGFloat = 16
        static let secondaryHorizontalPadding: CGFloat = 24
        static let earnTrailingPadding: CGFloat = 20
        static let secondaryTopPadding: CGFloat = 8
        static let placeholderTopPadding: CGFloat = 152
        static let actionsBarTopPadding: CGFloat = 8
    }
}
