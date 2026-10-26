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
    public var payment: Payment
    public var actionTitle: String
    public var limitText: String?
    public var isActionEnabled: Bool
    public var isActionLoading: Bool
    public var isLoading: Bool
    /// Replaces the rate and payment rows when there is nothing to buy with.
    public var placeholder: Placeholder?

    public struct Placeholder: Equatable {
        public var title: String
        public var subtitle: String?

        public init(title: String, subtitle: String? = nil) {
            self.title = title
            self.subtitle = subtitle
        }
    }

    public struct Payment: Equatable {
        public var title: String
        public var subtitle: String
        public var iconURL: URL?
        public var savedCard: MoonPaySavedCardIcon?
        public var badgeURL: URL?

        public init(
            title: String,
            subtitle: String,
            iconURL: URL?,
            savedCard: MoonPaySavedCardIcon? = nil,
            badgeURL: URL? = nil
        ) {
            self.title = title
            self.subtitle = subtitle
            self.iconURL = iconURL
            self.savedCard = savedCard
            self.badgeURL = badgeURL
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
        payment: Payment,
        actionTitle: String,
        limitText: String? = nil,
        isActionEnabled: Bool = true,
        isActionLoading: Bool = false,
        isLoading: Bool = false,
        placeholder: Placeholder? = nil
    ) {
        self.title = title
        self.payInCaption = payInCaption
        self.currencyCode = currencyCode
        self.currencyImageURL = currencyImageURL
        self.amount = amount
        self.rateText = rateText
        self.rateRestartToken = rateRestartToken
        self.payment = payment
        self.actionTitle = actionTitle
        self.limitText = limitText
        self.isActionEnabled = isActionEnabled
        self.isActionLoading = isActionLoading
        self.isLoading = isLoading
        self.placeholder = placeholder
    }
}

public struct MoonPayRampView: View {
    private let state: MoonPayRampViewState
    private let focus: FocusState<Bool>.Binding
    private let focusesOnAppear: Bool
    private let onTextChange: (String) -> Void
    private let onQuickOption: (String) -> Void
    private let onConvertedTap: () -> Void
    private let onCurrencyTap: () -> Void
    private let onToggleRateDirection: () -> Void
    private let onRateTimerCompleted: () -> Void
    private let onPaymentMethodTap: () -> Void
    private let onAction: () -> Void
    private let onClose: () -> Void

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
        onPaymentMethodTap: @escaping () -> Void,
        onAction: @escaping () -> Void,
        onClose: @escaping () -> Void
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
        self.onPaymentMethodTap = onPaymentMethodTap
        self.onAction = onAction
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
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
                        PlaceholderView(config: PlaceholderView.Config(
                            lottieResource: .creditCard,
                            title: placeholder.title,
                            subtitle: placeholder.subtitle
                        ))
                        .padding(.top, Layout.placeholderTopSpacing)
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
                    }
                }
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.top, Layout.contentTopSpacing)
                .padding(.bottom, Layout.contentBottomSpacing)
            }
            actionButton
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.top, Layout.actionTopSpacing)
                .padding(.bottom, Layout.actionBottomSpacing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
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
                        topPadding: 2
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
        if let limitText = state.limitText {
            Text(limitText)
                .textStyle(.body2)
                .foregroundStyle(.accentOrange)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: Layout.rateHitSize)
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
                duration: Layout.rateTimerDuration,
                onComplete: onRateTimerCompleted,
                restartToken: state.rateRestartToken
            )
            .padding(.trailing, 2)
            .frame(height: Layout.rateRowHeight)
            HStack(spacing: 4) {
                Text(state.rateText)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
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
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.rateHitSize)
    }

    private static let shimmerConfig = ShimmerSwiftUIView.Config(color: .backgroundContentTint, cornerRadius: .capsule)

    private var paymentShimmerRow: some View {
        HStack(spacing: Layout.paymentSpacing) {
            ShimmerSwiftUIView(config: Self.shimmerConfig)
                .frame(width: Layout.paymentIconSize, height: Layout.paymentIconSize)
            VStack(alignment: .leading, spacing: 2) {
                paymentShimmerLine(width: Layout.paymentShimmerTitleWidth, style: .label1)
                paymentShimmerLine(width: Layout.paymentShimmerSubtitleWidth, style: .body2)
            }
            Spacer(minLength: 8)
        }
        .padding(Layout.paymentPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.paymentCornerRadius, style: .continuous)
                .fill(.backgroundContent)
        )
    }

    private func paymentShimmerLine(width: CGFloat, style: TKTextStyle) -> some View {
        Text(" ")
            .textStyle(style)
            .hidden()
            .overlay(alignment: .leading) {
                ShimmerSwiftUIView(config: Self.shimmerConfig)
                    .frame(width: width, height: Layout.paymentShimmerLineHeight)
            }
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
                    Text(paymentSubtitle)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                SwiftUI.Image.TKUIKit.Icons.Size16.chevronDown
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.rateIconSize, height: Layout.rateIconSize)
                    .foregroundStyle(.iconTertiary)
            }
            .padding(Layout.paymentPadding)
            .background(
                RoundedRectangle(cornerRadius: Layout.paymentCornerRadius, style: .continuous)
                    .fill(.backgroundContent)
            )
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        .accessibilityLabel("\(paymentTitle), \(paymentSubtitle)")
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
            MoonPaySavedCardIconView(icon: savedCard, size: Layout.paymentIconSize)
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
                shape: .circle
            )
            .frame(width: Layout.paymentIconSize, height: Layout.paymentIconSize)
        }
    }

    private var paymentIcon: some View {
        paymentIconBase
            .overlay(alignment: .bottomTrailing) {
                if let badgeURL = state.payment.badgeURL {
                    AssetAvatarView(
                        imageSource: .url(badgeURL),
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
                    .offset(x: 6, y: 6)
                }
            }
    }

    private var paymentTitle: String {
        state.payment.title
    }

    private var paymentSubtitle: String {
        state.payment.subtitle
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let contentTopSpacing: CGFloat = 8
    static let contentBottomSpacing: CGFloat = 16
    static let rateTopSpacing: CGFloat = 4
    static let rateSpacing: CGFloat = 6
    static let rateRowHeight: CGFloat = 24
    static let rateIconSize: CGFloat = 16
    static let rateHitSize: CGFloat = 44
    static let rateTimerDuration: TimeInterval = 12
    static let placeholderTopSpacing: CGFloat = 32
    static let paymentShimmerTitleWidth: CGFloat = 90
    static let paymentShimmerSubtitleWidth: CGFloat = 60
    static let paymentShimmerLineHeight: CGFloat = 12
    static let paymentTopSpacing: CGFloat = 16
    static let paymentSpacing: CGFloat = 12
    static let paymentPadding: CGFloat = 16
    static let paymentCornerRadius: CGFloat = 16
    static let paymentIconSize: CGFloat = 36
    static let paymentBadgeSize: CGFloat = 16
    static let actionTopSpacing: CGFloat = 12
    static let actionBottomSpacing: CGFloat = 8
}
