import SwiftUI
import TKUIKit

public struct MoonPayRampViewState {
    public var title: String
    public var payInCaption: String
    public var currencyCode: String
    public var currencyImageURL: URL?
    public var amount: AmountInputSheetState
    public var rateText: String
    public var rateRestartToken: Int
    /// How long the loader runs before the rate is refreshed.
    public var rateTimerDuration: TimeInterval
    /// A quote is running though `rateText` is empty: its timer still refreshes it on expiry, so
    /// the row stays mounted, unseen.
    public var keepsRateTimer: Bool
    /// "incl. fees" after the rate, opening the quote's price details; nil when there are none.
    public var priceDetailsTitle: String?
    public var payment: Payment
    public var actionTitle: String
    public var isActionEnabled: Bool
    /// The payment can start now, from Continue or from the frame shown in its place.
    public var isPayable: Bool
    public var isActionLoading: Bool
    public var isLoading: Bool
    /// Replaces the rate and payment rows when there is nothing to buy with, and the action with
    /// its own two: change the currency or deposit crypto from another wallet.
    public var placeholder: Placeholder?
    /// The provider's legal texts for this payment, shown in full right above the action. Their
    /// links open in the browser.
    public var disclosures: [AttributedString]

    public struct Placeholder: Equatable {
        public var title: String
        public var subtitle: String?
        public var changeCurrencyTitle: String
        public var cryptoDepositTitle: String

        public init(title: String, subtitle: String? = nil, changeCurrencyTitle: String, cryptoDepositTitle: String) {
            self.title = title
            self.subtitle = subtitle
            self.changeCurrencyTitle = changeCurrencyTitle
            self.cryptoDepositTitle = cryptoDepositTitle
        }
    }

    public struct Payment: Equatable {
        /// The provider the purchase goes through, drawn over the payment method's icon.
        public enum Badge: Equatable {
            /// A merchant's logo from our backend.
            case url(URL)
            case moonPay
        }

        public var title: String
        public var subtitle: String
        public var iconURL: URL?
        public var savedCard: MoonPaySavedCardIcon?
        public var badge: Badge?

        public init(
            title: String,
            subtitle: String,
            iconURL: URL?,
            savedCard: MoonPaySavedCardIcon? = nil,
            badge: Badge? = nil
        ) {
            self.title = title
            self.subtitle = subtitle
            self.iconURL = iconURL
            self.savedCard = savedCard
            self.badge = badge
        }
    }

    public init(
        title: String,
        payInCaption: String,
        currencyCode: String,
        currencyImageURL: URL?,
        amount: AmountInputSheetState,
        rateText: String,
        rateRestartToken: Int,
        rateTimerDuration: TimeInterval = 12,
        keepsRateTimer: Bool = false,
        priceDetailsTitle: String? = nil,
        payment: Payment,
        actionTitle: String,
        isActionEnabled: Bool = true,
        isPayable: Bool? = nil,
        isActionLoading: Bool = false,
        isLoading: Bool = false,
        placeholder: Placeholder? = nil,
        disclosures: [AttributedString] = []
    ) {
        self.title = title
        self.payInCaption = payInCaption
        self.currencyCode = currencyCode
        self.currencyImageURL = currencyImageURL
        self.amount = amount
        self.rateText = rateText
        self.rateRestartToken = rateRestartToken
        self.rateTimerDuration = rateTimerDuration
        self.keepsRateTimer = keepsRateTimer
        self.priceDetailsTitle = priceDetailsTitle
        self.payment = payment
        self.actionTitle = actionTitle
        self.isActionEnabled = isActionEnabled
        self.isPayable = isPayable ?? isActionEnabled
        self.isActionLoading = isActionLoading
        self.isLoading = isLoading
        self.placeholder = placeholder
        self.disclosures = disclosures
    }
}

/// `InlineAction` takes the place of the action button while it is set, at its own size.
public struct MoonPayRampView<InlineAction: View>: View {
    private let state: MoonPayRampViewState
    private let focus: FocusState<Bool>.Binding
    private let focusesOnAppear: Bool
    private let onTextChange: (String) -> Void
    private let onQuickOption: (String) -> Void
    private let onConvertedTap: () -> Void
    private let onCurrencyTap: () -> Void
    private let onToggleRateDirection: () -> Void
    private let onRateTimerCompleted: () -> Void
    private let onPriceDetails: () -> Void
    private let onPaymentMethodTap: () -> Void
    private let onAction: () -> Void
    private let onCryptoDeposit: () -> Void
    private let onClose: () -> Void
    private let inlineAction: InlineAction?
    @State private var isKeyboardVisible = false

    public init(
        state: MoonPayRampViewState,
        focus: FocusState<Bool>.Binding,
        focusesOnAppear: Bool = false,
        onTextChange: @escaping (String) -> Void,
        onQuickOption: @escaping (String) -> Void,
        onConvertedTap: @escaping () -> Void,
        onCurrencyTap: @escaping () -> Void,
        onToggleRateDirection: @escaping () -> Void,
        onRateTimerCompleted: @escaping () -> Void,
        onPriceDetails: @escaping () -> Void = {},
        onPaymentMethodTap: @escaping () -> Void,
        onAction: @escaping () -> Void,
        onCryptoDeposit: @escaping () -> Void,
        onClose: @escaping () -> Void,
        inlineAction: InlineAction?
    ) {
        self.state = state
        self.focus = focus
        self.focusesOnAppear = focusesOnAppear
        self.onTextChange = onTextChange
        self.onQuickOption = onQuickOption
        self.onConvertedTap = onConvertedTap
        self.onCurrencyTap = onCurrencyTap
        self.onToggleRateDirection = onToggleRateDirection
        self.onRateTimerCompleted = onRateTimerCompleted
        self.onPriceDetails = onPriceDetails
        self.onPaymentMethodTap = onPaymentMethodTap
        self.onAction = onAction
        self.onCryptoDeposit = onCryptoDeposit
        self.onClose = onClose
        self.inlineAction = inlineAction
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            AmountInputSheet(
                                state: state.amount,
                                focus: focus,
                                onTextChange: onTextChange,
                                onToggle: {},
                                onMax: {},
                                onConvertedTap: onConvertedTap,
                                onQuickOption: onQuickOption
                            )
                            if let placeholder = state.placeholder {
                                placeholderView(placeholder)
                                    .frame(maxHeight: .infinity)
                            } else {
                                rateRow
                                    .padding(.top, Layout.rateTopSpacing)
                                Group {
                                    if state.isLoading {
                                        paymentShimmerRow
                                    } else {
                                        paymentRow
                                    }
                                }
                                .padding(.top, Layout.paymentTopSpacing)
                                if !state.disclosures.isEmpty {
                                    // In the scroll, so the amount and the method stay in view with the
                                    // keyboard up.
                                    disclosures
                                        .padding(.top, Layout.disclosureTopSpacing)
                                        .id(Self.disclosuresID)
                                }
                            }
                        }
                        .padding(.horizontal, Layout.horizontalInset)
                        .padding(.top, Layout.contentTopSpacing)
                        .padding(.bottom, Layout.contentBottomSpacing)
                        // The placeholder sits in the middle of the space under the amount.
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                    .onChange(of: isKeyboardVisible) { isVisible in
                        // The keyboard is down: bring the texts it may have hid into view before the payment.
                        guard !isVisible, !state.disclosures.isEmpty else { return }
                        withAnimation { scrollProxy.scrollTo(Self.disclosuresID, anchor: .bottom) }
                    }
                }
            }
            action
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.top, Layout.actionTopSpacing)
                .padding(.bottom, Layout.actionBottomSpacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        // From the frame, as the controller's inset is: it also arrives when the field takes over a
        // keyboard that was already up.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
            isKeyboardVisible = Self.isKeyboardOnScreen($0)
        }
        .onAppear {
            guard focusesOnAppear else { return }
            DispatchQueue.main.async { focus.wrappedValue = true }
        }
    }

    private var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                title: DefaultModalCardHeader.Title(text: state.title),
                subtitle: DefaultModalCardHeader.Subtitle(
                    text: state.payInCaption,
                    color: .textSecondary,
                    accentText: state.currencyCode,
                    accentColor: .accentBlue,
                    accentImageURL: state.currencyImageURL,
                    icon: .init(
                        image: .TKUIKit.Icons.Size16.switch,
                        size: 12,
                        topPadding: 4
                    ),
                    onTap: onCurrencyTap
                ),
                rightIcon: .close(onTap: { _ in onClose() }),
                height: .compact
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var rateRow: some View {
        if state.isLoading {
            ShimmerSwiftUIView(config: .init(color: .backgroundContent, cornerRadius: .capsule))
                .frame(width: Layout.rateShimmerSize.width, height: Layout.rateShimmerSize.height)
                .frame(maxWidth: .infinity, minHeight: Layout.rateHitSize)
        } else if state.rateText.isEmpty, state.keepsRateTimer {
            // Only the loader's completion refreshes an expiring quote, so it keeps running.
            quoteRateRow
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else if state.rateText.isEmpty {
            Color.clear.frame(height: Layout.rateHitSize)
        } else {
            quoteRateRow
        }
    }

    private var quoteRateRow: some View {
        HStack(spacing: Layout.rateSpacing) {
            CircularLoader(
                preset: .xSmall,
                duration: state.rateTimerDuration,
                onComplete: onRateTimerCompleted,
                restartToken: state.rateRestartToken
            )
            .padding(.trailing, 2)
            .frame(height: Layout.rateRowHeight)
            HStack(spacing: 4) {
                // The rate is what the row is for: "incl. fees" gives way first.
                Text(state.rateText)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
                Button(action: onToggleRateDirection) {
                    SwiftUI.Image.TKUIKit.Icons.Size16.swap
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Layout.rateIconSize, height: Layout.rateIconSize)
                        .foregroundStyle(.iconTertiary)
                }
                .buttonStyle(TKTapAnimationButtonStyle())
                .frame(height: Layout.rateRowHeight)
                .contentShape(Rectangle().inset(by: -(Layout.rateHitSize - Layout.rateIconSize) / 2))
                .accessibilityLabel(state.rateText)
                if let priceDetailsTitle = state.priceDetailsTitle {
                    priceDetailsButton(priceDetailsTitle)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.rateHitSize)
    }

    private func priceDetailsButton(_ title: String) -> some View {
        Button(action: onPriceDetails) {
            HStack(spacing: 4) {
                Text("·")
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                Text(title)
                    .underline()
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                SwiftUI.Image.TKUIKit.Icons.Size16.informationCircle
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.rateIconSize, height: Layout.rateIconSize)
                    .foregroundStyle(.iconTertiary)
            }
            .lineLimit(1)
            .frame(height: Layout.rateRowHeight)
            .contentShape(Rectangle().inset(by: -(Layout.rateHitSize - Layout.rateRowHeight) / 2))
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .accessibilityLabel(title)
    }

    private static var shimmerConfig: ShimmerSwiftUIView.Config {
        ShimmerSwiftUIView.Config(color: .backgroundContentTint, cornerRadius: .capsule)
    }

    /// The design's Cell / Skeleton: a 44 pt circle and two 12 pt lines in a 76 pt cell.
    private var paymentShimmerRow: some View {
        HStack(spacing: Layout.paymentShimmerSpacing) {
            ShimmerSwiftUIView(config: Self.shimmerConfig)
                .frame(width: Layout.paymentShimmerIconSize, height: Layout.paymentShimmerIconSize)
            VStack(alignment: .leading, spacing: Layout.paymentShimmerLineSpacing) {
                ShimmerSwiftUIView(config: Self.shimmerConfig)
                    .frame(width: Layout.paymentShimmerTitleWidth, height: Layout.paymentShimmerLineHeight)
                ShimmerSwiftUIView(config: Self.shimmerConfig)
                    .frame(width: Layout.paymentShimmerSubtitleWidth, height: Layout.paymentShimmerLineHeight)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.paymentPadding)
        .frame(height: Layout.paymentShimmerHeight)
        .background(
            RoundedRectangle(cornerRadius: Layout.paymentCornerRadius, style: .continuous)
                .fill(.backgroundContent)
        )
    }

    private var paymentRow: some View {
        Button(action: onPaymentMethodTap) {
            HStack(spacing: Layout.paymentSpacing) {
                paymentIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(paymentTitle)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    if !paymentSubtitle.isEmpty {
                        Text(paymentSubtitle)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                SwiftUI.Image.TKUIKit.Icons.Size16.switch
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.rateIconSize, height: Layout.rateIconSize)
                    .foregroundStyle(.iconTertiary)
                    .padding(.trailing, Layout.paymentSwitchTrailingInset)
            }
            .padding(Layout.paymentPadding)
            .background(
                RoundedRectangle(cornerRadius: Layout.paymentCornerRadius, style: .continuous)
                    .fill(.backgroundContent)
            )
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        .accessibilityLabel([paymentTitle, paymentSubtitle].filter { !$0.isEmpty }.joined(separator: ", "))
    }

    private func placeholderView(_ placeholder: MoonPayRampViewState.Placeholder) -> some View {
        VStack(spacing: Layout.placeholderTextSpacing) {
            Text(placeholder.title)
                .textStyle(.h3)
                .foregroundStyle(.textPrimary)
            if let subtitle = placeholder.subtitle {
                Text(subtitle)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.placeholderHorizontalInset)
        .padding(.vertical, Layout.placeholderVerticalInset)
    }

    private var disclosures: some View {
        VStack(spacing: Layout.disclosureSpacing) {
            ForEach(Array(state.disclosures.enumerated()), id: \.offset) { _, text in
                Text(text)
                    .textStyle(.body3)
                    .foregroundStyle(.textSecondary)
                    .tint(.accentBlue)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var action: some View {
        if let placeholder = state.placeholder {
            placeholderActions(placeholder)
        } else if let inlineAction {
            ZStack {
                // Stays in place, unseen, under the button that lowers the keyboard: a payment
                // frame loads only in a window, so it is ready once the keyboard is down.
                inlineAction
                    .opacity(revealsDisclosures ? 0 : 1)
                    .allowsHitTesting(!revealsDisclosures)
                    .accessibilityHidden(revealsDisclosures)
                if revealsDisclosures {
                    revealButton
                }
            }
        } else if revealsDisclosures {
            revealButton
        } else {
            actionButton
        }
    }

    private var revealButton: some View {
        ButtonView(config: .init(
            title: state.actionTitle,
            size: .large,
            layoutMode: .fill,
            appearance: .primary,
            showsLoader: state.isActionLoading,
            action: {
                focus.wrappedValue = false
                // Also a keyboard the field took over without its focus state following.
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                // Set here too: a hide frame that never arrives must not keep the payment out of reach.
                isKeyboardVisible = false
            }
        ))
        // Stands in for the action while the keyboard is up, so it is off whenever the payment is:
        // a refreshing quote dims it in place rather than swapping in a disabled Apple Pay button.
        .disabled(!state.isPayable || state.isActionLoading)
    }

    /// The provider's texts may sit under the keyboard while it is up, so the first tap on the
    /// action, an Apple Pay button included, only lowers it; texts already in view cost that tap too,
    /// a deliberate trade for a rule that does not depend on measuring them.
    private var revealsDisclosures: Bool {
        isKeyboardVisible && !state.disclosures.isEmpty
    }

    private static func isKeyboardOnScreen(_ notification: Notification) -> Bool {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return false
        }
        return frame.height > 0 && frame.minY < UIScreen.main.bounds.maxY - 1
    }

    private static var disclosuresID: String {
        "disclosures"
    }

    private func placeholderActions(_ placeholder: MoonPayRampViewState.Placeholder) -> some View {
        VStack(spacing: Layout.placeholderActionSpacing) {
            ButtonView(config: .init(
                title: placeholder.changeCurrencyTitle,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: onCurrencyTap
            ))
            ButtonView(config: .init(
                title: placeholder.cryptoDepositTitle,
                size: .large,
                layoutMode: .fill,
                appearance: .secondary,
                action: onCryptoDeposit
            ))
        }
    }

    private var actionButton: some View {
        ButtonView(config: .init(
            title: state.actionTitle,
            size: .large,
            layoutMode: .fill,
            appearance: .primary,
            showsLoader: state.isActionLoading,
            action: onAction
        ))
        .disabled(!state.isActionEnabled || state.isActionLoading)
    }

    @ViewBuilder
    private var paymentIconBase: some View {
        if let savedCard = state.payment.savedCard {
            // As wide as the payment method screen's card; the row keeps the avatars' height.
            MoonPaySavedCardIconView(icon: savedCard, size: Layout.savedCardWidth)
                .frame(height: Layout.paymentIconSize)
        } else {
            AssetAvatarView(
                imageSource: .url(state.payment.iconURL),
                configuration: AssetAvatarView.Configuration(
                    imageSize: Layout.paymentIconSize,
                    chainIconSize: 0,
                    chainIconPadding: 0,
                    chainIconOffsetX: 0,
                    chainIconOffsetY: 0
                ),
                shape: .circle,
                imageBackgroundColor: .clear
            )
            .frame(width: Layout.paymentIconSize, height: Layout.paymentIconSize)
        }
    }

    private var paymentIcon: some View {
        paymentIconBase
            .overlay(alignment: .bottomTrailing) {
                if let badge = state.payment.badge {
                    AssetAvatarView(
                        imageSource: badgeImageSource(badge),
                        configuration: AssetAvatarView.Configuration(
                            imageSize: Layout.paymentBadgeSize,
                            chainIconSize: 0,
                            chainIconPadding: 0,
                            chainIconOffsetX: 0,
                            chainIconOffsetY: 0
                        ),
                        shape: .circle
                    )
                    .frame(width: Layout.paymentBadgeSize, height: Layout.paymentBadgeSize)
                    .padding(2)
                    .background(Circle().fill(.backgroundContent))
                    .offset(badgeOffset)
                }
            }
    }

    /// The design anchors a saved card's badge to the card's 44 pt square slot, not to the card:
    /// 4 pt past the card on the right and 11 pt below it. The 36 pt frame the card sits in ends
    /// 3 pt below the card, hence 8.
    private var badgeOffset: CGSize {
        state.payment.savedCard == nil ? CGSize(width: 6, height: 6) : CGSize(width: 4, height: 8)
    }

    private func badgeImageSource(_ badge: MoonPayRampViewState.Payment.Badge) -> AssetAvatarViewImageSource {
        switch badge {
        case let .url(url): .url(url)
        case .moonPay: .image(.TKUIKit.Artwork.Providers.moonpay)
        }
    }

    private var paymentTitle: String {
        state.payment.title
    }

    private var paymentSubtitle: String {
        state.payment.subtitle
    }
}

public extension MoonPayRampView where InlineAction == EmptyView {
    init(
        state: MoonPayRampViewState,
        focus: FocusState<Bool>.Binding,
        focusesOnAppear: Bool = false,
        onTextChange: @escaping (String) -> Void,
        onQuickOption: @escaping (String) -> Void,
        onConvertedTap: @escaping () -> Void,
        onCurrencyTap: @escaping () -> Void,
        onToggleRateDirection: @escaping () -> Void,
        onRateTimerCompleted: @escaping () -> Void,
        onPriceDetails: @escaping () -> Void = {},
        onPaymentMethodTap: @escaping () -> Void,
        onAction: @escaping () -> Void,
        onCryptoDeposit: @escaping () -> Void = {},
        onClose: @escaping () -> Void
    ) {
        self.init(
            state: state,
            focus: focus,
            focusesOnAppear: focusesOnAppear,
            onTextChange: onTextChange,
            onQuickOption: onQuickOption,
            onConvertedTap: onConvertedTap,
            onCurrencyTap: onCurrencyTap,
            onToggleRateDirection: onToggleRateDirection,
            onRateTimerCompleted: onRateTimerCompleted,
            onPriceDetails: onPriceDetails,
            onPaymentMethodTap: onPaymentMethodTap,
            onAction: onAction,
            onCryptoDeposit: onCryptoDeposit,
            onClose: onClose,
            inlineAction: nil
        )
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let disclosureSpacing: CGFloat = 12
    static let disclosureTopSpacing: CGFloat = 12
    static let contentTopSpacing: CGFloat = 8
    static let contentBottomSpacing: CGFloat = 16
    static let rateTopSpacing: CGFloat = 2
    static let rateSpacing: CGFloat = 6
    static let rateRowHeight: CGFloat = 24
    static let rateIconSize: CGFloat = 16
    static let rateHitSize: CGFloat = 44
    static let placeholderTextSpacing: CGFloat = 4
    // The design's 32 pt empty-state inset plus its 24 pt text inset, past the screen's 16.
    static let placeholderHorizontalInset: CGFloat = 40
    static let placeholderVerticalInset: CGFloat = 64
    static let placeholderActionSpacing: CGFloat = 16
    static let paymentShimmerTitleWidth: CGFloat = 72
    static let paymentShimmerSubtitleWidth: CGFloat = 64
    static let paymentShimmerLineHeight: CGFloat = 12
    static let paymentShimmerLineSpacing: CGFloat = 8
    static let paymentShimmerSpacing: CGFloat = 16
    static let paymentShimmerIconSize: CGFloat = 44
    static let paymentShimmerHeight: CGFloat = 76
    static let rateShimmerSize = CGSize(width: 150, height: 16)
    static let paymentTopSpacing: CGFloat = 10
    static let paymentSpacing: CGFloat = 16
    /// The design's 22 pt from the switch icon to the cell's edge, past the cell's 16.
    static let paymentSwitchTrailingInset: CGFloat = 6
    static let paymentPadding: CGFloat = 16
    static let paymentCornerRadius: CGFloat = 16
    static let paymentIconSize: CGFloat = 36
    static let savedCardWidth: CGFloat = 44
    static let paymentBadgeSize: CGFloat = 16
    static let actionTopSpacing: CGFloat = 12
    static let actionBottomSpacing: CGFloat = 8
}
