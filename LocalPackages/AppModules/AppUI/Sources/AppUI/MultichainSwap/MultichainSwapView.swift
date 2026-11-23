import SwiftUI
import TKLocalize
import TKUIKit

public struct MultichainSwapView: View {
    public let state: MultichainSwapViewState
    public let actions: MultichainSwapViewActions

    @FocusState private var focusedAmountField: MultichainSwapAmountField?
    @State private var swapRotation: CGFloat = 0

    public init(
        state: MultichainSwapViewState,
        actions: MultichainSwapViewActions
    ) {
        self.state = state
        self.actions = actions
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            content
        }
        // Closed while a swap is on its way, the screen would take the swap's outcome along.
        .disabled(state.isSwapping)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        // The scroll view and the header take the taps that land on them, so only the container sees a
        // tap that no control claims, and that tap closes the keyboard.
        .contentShape(Rectangle())
        .onTapGesture {
            focusedAmountField = nil
        }
        .task {
            focus(state.focusField, isLoaded: state.isLoaded)
        }
        // This `onChange` runs with the values captured before the change, so `state` there is the
        // old one; the new value comes in as the parameter. A screen that has just loaded has nothing
        // entered but the send amount.
        .onChange(of: state.isLoaded) { isLoaded in
            focus(.send, isLoaded: isLoaded)
        }
        // The field comes with the request: a token pick can move it in the same update.
        .onChange(of: FocusRequest(id: state.focusRequestID, field: state.focusField)) { request in
            focus(request.field, isLoaded: state.isLoaded)
        }
    }
}

private extension MultichainSwapView {
    @ViewBuilder
    var content: some View {
        switch state.content {
        case .shimmer:
            shimmerContent
        case .error:
            errorContent
        case let .loaded(loadedState):
            loadedContent(loadedState)
        }
    }

    var errorContent: some View {
        VStack(spacing: 0) {
            PlaceholderView(
                config: PlaceholderView.Config(
                    lottieResource: .exclamationmarkCircle,
                    title: TKLocales.Trade.Placeholder.errorTitle,
                    subtitle: TKLocales.Trade.Placeholder.errorSubtitle,
                    button: PlaceholderView.ButtonConfig(
                        title: TKLocales.Actions.retry,
                        icon: .TKUIKit.Icons.Size16.refresh,
                        action: actions.retryLoading
                    )
                )
            )
            .padding(.top, Layout.errorTopPadding)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, Layout.errorHorizontalInset)
    }

    @ViewBuilder
    var headerView: some View {
        if let promoTitle = state.promoTitle {
            promoHeader(promoTitle: promoTitle)
        } else {
            DefaultModalCardHeader(
                config: .init(
                    title: .init(
                        text: TKLocales.NativeSwap.Screen.Swap.title
                    ),
                    rightIcon: .close { _ in
                        actions.close()
                    }
                )
            )
        }
    }

    func promoHeader(promoTitle: String) -> some View {
        ModalCardHeader(
            config: .init(headerContentAlignment: .center)
        ) {
            EmptyView()
        } center: {
            Button(action: actions.openRaffle) {
                VStack(spacing: -1) {
                    Text(TKLocales.NativeSwap.Screen.Swap.title)
                        .textStyle(.h3)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                        .padding(.top, Layout.headerTitleTopPadding)
                    RaffleSwapPromoView(title: promoTitle)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(TKTapAnimationButtonStyle())
        } trailing: {
            headerCloseButton
        }
        .frame(height: Layout.headerHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.headerHorizontalInset)
        .background(.backgroundPage)
    }

    var headerCloseButton: some View {
        Button(action: actions.close) {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.close)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.buttonSecondaryForeground)
                .padding(8)
                .background(.buttonSecondaryBackground)
                .clipShape(Circle())
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .padding(.top, Layout.headerIconTopPadding)
    }

    func loadedContent(_ loadedState: MultichainSwapViewState.Loaded) -> some View {
        VStack(spacing: 0) {
            // On short screens the keyboard leaves less room than the cards need, and the action bar
            // has to stay above it.
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        sendCard(loadedState.sendCard)
                        receiveCard(loadedState.receiveCard)
                    }
                    .overlay(alignment: .center, content: {
                        swapDirectionButton
                    })
                    .padding(.horizontal, 16)

                    quoteRow(
                        loadedState.quote,
                        canContinue: loadedState.continueButton.isEnabled && state.sendFailure == nil
                    )
                    .padding(.horizontal, 16)
                }
            }
            .tkImmediateButtonPresses()
            ZStack {
                if let sendFailure = state.sendFailure {
                    sendFailureBar(sendFailure)
                        .transition(.opacity)
                } else {
                    actionBar(loadedState.continueButton)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: Layout.sendFailureFadeDuration), value: state.sendFailure)
        }
    }

    func sendCard(_ card: MultichainSwapViewState.AmountCard) -> some View {
        MultichainSwapAmountCard(
            config: .content(
                MultichainSwapAmountCardContent(
                    amount: Binding(
                        get: { card.amount },
                        set: actions.updateSendAmount
                    ),
                    amountPrefix: card.amountPrefix,
                    amountState: card.amountState,
                    showsQuoteShimmer: card.showsQuoteShimmer,
                    quoteUnavailableText: card.quoteUnavailableText,
                    exceedsBalance: card.exceedsBalance,
                    balanceText: card.balanceText,
                    rateText: card.rateText,
                    maximumFractionDigits: card.maximumFractionDigits,
                    decimalSeparator: card.decimalSeparator,
                    field: .send,
                    focusedField: $focusedAmountField,
                    tokenAvatarSource: card.token.avatarSource,
                    tokenSymbol: card.token.symbol,
                    network: card.token.network,
                    onTapCard: {
                        focusedAmountField = .send
                    },
                    onTapRateText: actions.toggleSendAmountInputMode,
                    onTapToken: actions.requestPickSendToken,
                    numPadPresets: sendPercentPresets
                )
            )
        )
    }

    func receiveCard(_ card: MultichainSwapViewState.AmountCard) -> some View {
        MultichainSwapAmountCard(
            config: .content(
                MultichainSwapAmountCardContent(
                    amount: Binding(
                        get: { card.amount },
                        set: actions.updateReceiveAmount
                    ),
                    amountPrefix: card.amountPrefix,
                    amountState: card.amountState,
                    showsQuoteShimmer: card.showsQuoteShimmer,
                    quoteUnavailableText: card.quoteUnavailableText,
                    balanceText: card.balanceText,
                    rateText: card.rateText,
                    showsRateToggleIcon: false,
                    priceImpact: card.priceImpact.map { priceImpact in
                        MultichainSwapAmountCardContent.PriceImpact(
                            text: priceImpact.text,
                            color: priceImpact.severity.color,
                            onTap: actions.openPriceImpactInfo
                        )
                    },
                    maximumFractionDigits: card.maximumFractionDigits,
                    decimalSeparator: card.decimalSeparator,
                    field: .receive,
                    focusedField: $focusedAmountField,
                    tokenAvatarSource: card.token.avatarSource,
                    tokenSymbol: card.token.symbol,
                    network: card.token.network,
                    onTapCard: {
                        focusedAmountField = .receive
                    },
                    onTapRateText: actions.toggleReceiveAmountInputMode,
                    onTapToken: actions.requestPickReceiveToken
                )
            )
        )
    }

    var swapDirectionButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                swapRotation += .pi
                actions.swapTokens()
                focusedAmountField = .send
            }
        } label: {
            SwiftUI.Image.TKUIKit.Icons.Size16.swapVertical
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.buttonTertiaryForeground)
                .frame(width: 48, height: 48)
                .rotationEffect(.radians(swapRotation))
        }
        .buttonStyle(SwapDirectionButtonStyle())
    }

    func quoteRow(_ quote: MultichainSwapViewState.Quote, canContinue: Bool) -> some View {
        Group {
            switch quote.mode {
            case .hidden:
                Color.clear
            case let .batteryPromo(text):
                batteryPromoButton(text)
            // One branch for both: the loader keeps turning when only the text changes.
            case .loading, .estimatingFee:
                HStack(spacing: Layout.quoteLoaderSpacing) {
                    CircularLoader(mode: .indeterminate, preset: .xSmall)
                    rateRowText(
                        quote.mode == .loading
                            ? TKLocales.NativeSwap.Quote.Rate.updating
                            : TKLocales.MultichainSwap.Screen.Swap.NetworkFee.estimating,
                        color: .textSecondary
                    )
                }
            case let .failed(message):
                quoteAlert(message, color: .accentRed)
            case let .fee(fee):
                feeButton(fee, canContinue: canContinue)
            }
        }
        .frame(minHeight: Layout.quoteRowHeight)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    func feeButton(_ fee: MultichainSwapViewState.Quote.Fee, canContinue: Bool) -> some View {
        Button(action: actions.openPricingDetails) {
            HStack(spacing: Layout.feeRowSpacing) {
                if let icon = fee.icon {
                    icon.image
                        .renderingMode(.template)
                        .foregroundStyle(fee.isShortage ? TKColor.accentRed : TKColor.iconTertiary)
                }
                rateRowText(fee.text, color: fee.isShortage ? .accentRed : .textSecondary)
                // A swap that cannot go opens no pricing details, so its row offers none.
                if canContinue {
                    SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight
                        .renderingMode(.template)
                        .foregroundStyle(.iconTertiary)
                }
            }
            .frame(height: Layout.quoteRowHeight)
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .disabled(!canContinue)
        .accessibilityIdentifier("swap_network_fee")
    }

    func batteryPromoButton(_ text: String) -> some View {
        Button(action: actions.openBatteryPromo) {
            HStack(spacing: Layout.feeRowSpacing) {
                MultichainSwapViewState.Quote.Fee.Icon.battery.image
                    .renderingMode(.template)
                rateRowText(text, color: .accentBlue)
                SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight
                    .renderingMode(.template)
            }
            .foregroundStyle(.accentBlue)
            .frame(height: Layout.quoteRowHeight)
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .accessibilityIdentifier("swap_battery_promo")
    }

    /// The mark stays on the first line when the text wraps.
    func quoteAlert(_ text: String, color: TKColor) -> some View {
        HStack(alignment: .top, spacing: Layout.quoteAlertIconSpacing) {
            SwiftUI.Image.TKUIKit.Icons.Size16.exclamationMarkCircle
                .renderingMode(.template)
                .foregroundStyle(color)
                .padding(.top, Layout.quoteAlertIconTopPadding)
            rateRowText(text, color: color, lineLimit: nil)
        }
    }

    func rateRowText(_ text: String, color: TKColor, lineLimit: Int? = 1) -> some View {
        Text(text)
            .textStyle(.body2)
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.center)
    }

    var shimmerContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                MultichainSwapAmountCard(config: .shimmer(.send))
                MultichainSwapAmountCard(config: .shimmer(.receive))
            }
            .overlay(alignment: .center) {
                Circle()
                    .fill(.buttonTertiaryBackground)
                    .frame(width: 40, height: 40)
                    .padding(4)
            }
            .padding(.horizontal, 16)

            HStack {
                Spacer()
                ShimmerSwiftUIView(
                    config: .init(
                        color: .backgroundContent,
                        cornerRadius: .value(8)
                    )
                )
                .frame(width: 150, height: 12)
                .padding(.bottom, 4)
                Spacer()
            }
            .frame(height: 48)
            .padding(.horizontal, 16)

            Spacer()
            ButtonView(config: continueButtonConfig(.blocked(TKLocales.WalletButtons.swap)))
                .disabled(true)
                .padding(16)
        }
    }

    var sendPercentPresets: [TKNumPadPreset] {
        Layout.sendPercentPresets.map { percent in
            TKNumPadPreset(title: percent == 100 ? TKLocales.Common.Numbers.max : "\(percent)%") {
                actions.applySendPercent(percent)
            }
        }
    }

    func actionBar(_ continueButton: MultichainSwapViewState.ContinueButton) -> some View {
        VStack(spacing: 0) {
            if !TKNumPadView.isEnabled {
                HStack(spacing: 8) {
                    ForEach(sendPercentPresets, id: \.title) { preset in
                        ButtonView(
                            config: .init(
                                title: preset.title,
                                size: .small,
                                layoutMode: .fill,
                                appearance: .secondary,
                                action: preset.action
                            )
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            ButtonView(config: continueButtonConfig(continueButton))
                .disabled(!continueButton.isEnabled)
                .accessibilityIdentifier("swap_continue")
                .padding(16)
        }
    }

    func continueButtonConfig(_ continueButton: MultichainSwapViewState.ContinueButton) -> ButtonView.Config {
        switch continueButton {
        case .swap:
            ButtonView.Config(
                title: TKLocales.WalletButtons.swap,
                size: .large,
                layoutMode: .fill,
                appearance: state.isSwapping ? .secondary : .primary,
                showsLoader: state.isSwapping,
                action: actions.continueSwap
            )
        case let .blocked(title):
            ButtonView.Config(
                title: title,
                size: .large,
                layoutMode: .fill,
                appearance: .secondary,
                action: actions.continueSwap
            )
        case .feeUnpaid:
            ButtonView.Config(
                title: TKLocales.WalletButtons.swap,
                size: .large,
                layoutMode: .fill,
                appearance: .secondary,
                showsLoader: state.isSwapping,
                action: actions.continueSwap
            )
        case .topUpBattery:
            ButtonView.Config(
                title: TKLocales.MultichainSwap.Screen.Confirm.topUpBattery,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: actions.topUpBattery
            )
        }
    }

    func sendFailureBar(_ title: String) -> some View {
        TKResultSwiftUIView(state: .failure, title: title)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.sendFailureHeight)
    }

    /// Asked on the next run loop: the field may come into existence in the same update.
    func focus(_ field: MultichainSwapAmountField, isLoaded: Bool) {
        guard isLoaded else {
            return
        }
        DispatchQueue.main.async {
            focusedAmountField = field
        }
    }

    struct FocusRequest: Equatable {
        let id: Int
        let field: MultichainSwapAmountField
    }

    enum Layout {
        static let headerHeight: CGFloat = 72
        static let headerHorizontalInset: CGFloat = 16
        static let headerTitleTopPadding: CGFloat = 8
        static let headerIconTopPadding: CGFloat = 16
        static let errorHorizontalInset: CGFloat = 32
        static let errorTopPadding: CGFloat = 32
        static let sendPercentPresets = [25, 50, 75, 100]
        static let quoteRowHeight: CGFloat = 24
        static let quoteLoaderSpacing: CGFloat = 4
        static let feeRowSpacing: CGFloat = 4
        static let quoteAlertIconSpacing: CGFloat = 6
        static let quoteAlertIconTopPadding: CGFloat = 2
        static let sendFailureHeight: CGFloat = 88
        static let sendFailureFadeDuration: TimeInterval = 0.3
    }
}

private extension MultichainSwapViewState.Quote.Fee.Icon {
    var image: SwiftUI.Image {
        switch self {
        case .battery:
            .TKUIKit.Icons.Size16.battery
        case .exclamationMark:
            .TKUIKit.Icons.Size16.exclamationMarkCircle
        }
    }
}

private struct SwapDirectionButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(
                        configuration.isPressed
                            ? TKColor.buttonTertiaryBackgroundHighlighted
                            : TKColor.buttonTertiaryBackground
                    )
            )
            .animation(.easeInOut(duration: 0.14), value: configuration.isPressed)
            .tkTapAnimation(isPressed: configuration.isPressed, haptic: .light)
    }
}
