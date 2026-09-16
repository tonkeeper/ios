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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            TKColor.backgroundPage
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedAmountField = nil
                }
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            focusSendFieldIfLoaded()
        }
        .onChange(of: state.isLoaded) { _ in
            focusSendFieldIfLoaded()
        }
        .onChange(of: state.focusRequestID) { _ in
            focusSendFieldIfLoaded()
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
            VStack(spacing: 8) {
                sendCard(loadedState.sendCard)
                receiveCard(loadedState.receiveCard)
            }
            .overlay(alignment: .center, content: {
                swapDirectionButton
            })
            .padding(.horizontal, 16)

            rateRow(loadedState.quote)
                .padding(.horizontal, 16)
            Spacer()
            continueButton(action: actions.continueSwap)
                .disabled(!loadedState.canContinue)
                .accessibilityIdentifier("swap_continue")
                .padding(16)
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
                    insufficientBalance: card.insufficientBalanceText,
                    balanceText: card.balanceText,
                    rateText: card.rateText,
                    maximumFractionDigits: card.maximumFractionDigits,
                    decimalSeparator: card.decimalSeparator,
                    field: .send,
                    focusedField: $focusedAmountField,
                    tokenAvatarSource: card.token.avatarSource,
                    tokenSymbol: card.token.symbol,
                    network: card.token.network,
                    maxTitle: TKLocales.Common.Numbers.max,
                    onTapCard: {
                        focusedAmountField = .send
                    },
                    onTapMax: actions.applyMaxSend,
                    onTapRateText: actions.toggleSendAmountInputMode,
                    onTapToken: actions.requestPickSendToken
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
                        set: { _ in }
                    ),
                    amountPrefix: card.amountPrefix,
                    amountState: card.amountState,
                    showsQuoteShimmer: card.showsQuoteShimmer,
                    quoteUnavailableText: card.quoteUnavailableText,
                    balanceText: card.balanceText,
                    rateText: card.rateText,
                    showsRateToggleIcon: false,
                    maximumFractionDigits: card.maximumFractionDigits,
                    decimalSeparator: card.decimalSeparator,
                    field: .receive,
                    focusedField: $focusedAmountField,
                    tokenAvatarSource: card.token.avatarSource,
                    tokenSymbol: card.token.symbol,
                    network: card.token.network,
                    onTapCard: {},
                    onTapMax: {},
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

    func rateRow(_ quote: MultichainSwapViewState.Quote) -> some View {
        HStack(spacing: 6) {
            switch quote.mode {
            case .idle:
                EmptyView()
            case .loading:
                rateRowText(quote.rateText, color: .textSecondary)
                CircularLoader(mode: .indeterminate, preset: .xSmall)
                    .padding(.leading, 2)
                    .frame(height: 24)
            case .failed:
                rateRowText(quote.rateText, color: .accentRed, lineLimit: nil)
            case .ready:
                CircularLoader(
                    preset: .xSmall,
                    duration: quote.refreshDuration,
                    onComplete: actions.notifyQuoteRefreshCompleted,
                    restartToken: quote.progressRestartToken
                )
                .padding(.trailing, 2)
                .frame(height: 24)
                HStack(spacing: 4) {
                    rateRowText(quote.rateText, color: .textSecondary)
                    Button(action: actions.toggleRateDisplayDirection) {
                        SwiftUI.Image.TKUIKit.Icons.Size16.swap
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.iconTertiary)
                    }
                    .buttonStyle(TKTapAnimationButtonStyle())
                    .frame(height: 24)
                }
            case .expired:
                rateRowText(quote.rateText, color: .textSecondary)
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
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
            continueButton(action: {})
                .disabled(true)
                .accessibilityIdentifier("swap_continue")
                .padding(16)
        }
    }

    func continueButton(action: @escaping () -> Void) -> some View {
        ButtonView(
            config: .init(
                title: TKLocales.Actions.continueAction,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: action
            )
        )
    }

    func focusSendFieldIfLoaded() {
        guard state.isLoaded else {
            return
        }
        focusedAmountField = .send
        DispatchQueue.main.async {
            focusedAmountField = .send
        }
    }

    enum Layout {
        static let headerHeight: CGFloat = 72
        static let headerHorizontalInset: CGFloat = 16
        static let headerTitleTopPadding: CGFloat = 8
        static let headerIconTopPadding: CGFloat = 16
        static let errorHorizontalInset: CGFloat = 32
        static let errorTopPadding: CGFloat = 32
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
