import SwiftUI
import TKLocalize

public enum MultichainSwapAmountField: Hashable, Sendable {
    case send
    case receive
}

public enum MultichainSwapAmountState: Hashable, Sendable {
    case editable
    case loading
    case disabled
}

public enum MultichainSwapAmountCardConfig {
    case shimmer(MultichainSwapAmountField)
    case content(MultichainSwapAmountCardContent)

    var field: MultichainSwapAmountField {
        switch self {
        case let .shimmer(field):
            field
        case let .content(content):
            content.field
        }
    }
}

public struct MultichainSwapAmountCardContent {
    public var amount: Binding<String>
    /// Fixed text rendered ahead of the amount input (e.g. a currency symbol in
    /// fiat mode). Not part of the editable text, so it cannot be deleted.
    public var amountPrefix: String?
    public var amountState: MultichainSwapAmountState
    public var showsQuoteShimmer: Bool
    public var quoteUnavailableText: String?
    public var insufficientBalance: String?
    public var balanceText: String?
    public var rateText: String?
    public var showsRateToggleIcon: Bool
    public var maximumFractionDigits: Int?
    /// Separator the input is normalized to, so typed and formatted amounts agree with the app locale.
    public var decimalSeparator: String
    public var field: MultichainSwapAmountField
    public var focusedField: FocusState<MultichainSwapAmountField?>.Binding
    public var tokenAvatarSource: AssetAvatarViewImageSource
    public var tokenSymbol: String
    public var maxTitle: String?

    public var onTapCard: () -> Void
    public var onTapMax: () -> Void
    public var onTapRateText: (() -> Void)?
    public var onTapToken: () -> Void

    public init(
        amount: Binding<String>,
        amountPrefix: String? = nil,
        amountState: MultichainSwapAmountState = .editable,
        showsQuoteShimmer: Bool = false,
        quoteUnavailableText: String? = nil,
        insufficientBalance: String? = nil,
        balanceText: String?,
        rateText: String? = nil,
        showsRateToggleIcon: Bool = true,
        maximumFractionDigits: Int? = nil,
        decimalSeparator: String = ".",
        field: MultichainSwapAmountField,
        focusedField: FocusState<MultichainSwapAmountField?>.Binding,
        tokenAvatarSource: AssetAvatarViewImageSource,
        tokenSymbol: String,
        network: String?,
        maxTitle: String? = nil,
        onTapCard: @escaping () -> Void,
        onTapMax: @escaping () -> Void,
        onTapRateText: (() -> Void)? = nil,
        onTapToken: @escaping () -> Void
    ) {
        self.amount = amount
        self.amountPrefix = amountPrefix
        self.amountState = amountState
        self.showsQuoteShimmer = showsQuoteShimmer
        self.quoteUnavailableText = quoteUnavailableText
        self.insufficientBalance = insufficientBalance
        self.balanceText = balanceText
        self.rateText = rateText
        self.showsRateToggleIcon = showsRateToggleIcon
        self.maximumFractionDigits = maximumFractionDigits
        self.decimalSeparator = decimalSeparator
        self.field = field
        self.focusedField = focusedField
        self.tokenAvatarSource = tokenAvatarSource
        self.tokenSymbol = tokenSymbol
        self.maxTitle = maxTitle
        self.onTapCard = onTapCard
        self.onTapMax = onTapMax
        self.onTapRateText = onTapRateText
        self.onTapToken = onTapToken
    }
}

public struct MultichainSwapAmountCard: View {
    private let config: MultichainSwapAmountCardConfig

    @State private var lastAmount = ""

    public init(config: MultichainSwapAmountCardConfig) {
        self.config = config
    }

    public init(
        amount: Binding<String>,
        amountState: MultichainSwapAmountState = .editable,
        balanceText: String?,
        rateText: String? = nil,
        maximumFractionDigits: Int? = nil,
        field: MultichainSwapAmountField,
        focusedField: FocusState<MultichainSwapAmountField?>.Binding,
        tokenAvatarSource: AssetAvatarViewImageSource,
        tokenSymbol: String,
        network: String?,
        maxTitle: String? = nil,
        onTapCard: @escaping () -> Void,
        onTapMax: @escaping () -> Void,
        onTapToken: @escaping () -> Void
    ) {
        self.config = .content(
            MultichainSwapAmountCardContent(
                amount: amount,
                amountState: amountState,
                balanceText: balanceText,
                rateText: rateText,
                maximumFractionDigits: maximumFractionDigits,
                field: field,
                focusedField: focusedField,
                tokenAvatarSource: tokenAvatarSource,
                tokenSymbol: tokenSymbol,
                network: network,
                maxTitle: maxTitle,
                onTapCard: onTapCard,
                onTapMax: onTapMax,
                onTapToken: onTapToken
            )
        )
    }

    public var body: some View {
        switch config {
        case .shimmer:
            shimmerView
        case let .content(content):
            contentView(content)
        }
    }

    private func contentView(_ content: MultichainSwapAmountCardContent) -> some View {
        VStack(alignment: .leading, spacing: Layout.zeroSpacing) {
            headerView
                .padding(.top, Layout.headerTopPadding)
                .padding(.horizontal, Layout.horizontalPadding)

            amountRow(content)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, content.showsQuoteShimmer ? Layout.amountFooterShimmerSpacing : Layout.amountFooterSpacing)

            footerView(content)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, Layout.footerBottomPadding)

            Spacer(minLength: Layout.zeroSpacing)
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(fieldBackgroundColor(for: content))
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .strokeBorder(fieldBorderColor(for: content), lineWidth: Layout.borderWidth)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard content.amountState == .editable else {
                return
            }
            content.onTapCard()
        }
    }

    private var shimmerView: some View {
        VStack(alignment: .leading, spacing: Layout.zeroSpacing) {
            headerView
                .padding(.top, Layout.headerTopPadding)
                .padding(.horizontal, Layout.horizontalPadding)

            HStack(alignment: .top, spacing: Layout.amountRowSpacing) {
                shimmerBlock(width: 104, height: 36)
                    .padding(.top, 5)
                Spacer(minLength: 0)
                shimmerBlock(width: 104, height: 40)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, 4)

            HStack {
                shimmerBlock(width: Layout.shimmerFooterLeadingWidth, height: Layout.shimmerLineHeight)
                Spacer(minLength: Layout.footerSpacerMinLength)
                shimmerBlock(width: Layout.shimmerFooterTrailingWidth, height: Layout.shimmerLineHeight)
            }
            .frame(height: Layout.footerHeight)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.shimmerFooterTopPadding)

            Spacer(minLength: Layout.zeroSpacing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: cardHeight)
        .background(.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
    }

    private var cardHeight: CGFloat {
        switch config.field {
        case .send:
            Layout.sendCardHeight
        case .receive:
            Layout.receiveCardHeight
        }
    }

    private var headerTitle: String {
        switch config.field {
        case .send:
            TKLocales.NativeSwap.Field.send
        case .receive:
            TKLocales.NativeSwap.Field.receive
        }
    }
}

private extension MultichainSwapAmountCard {
    var headerView: some View {
        HStack(alignment: .top, spacing: Layout.headerSpacing) {
            Text(headerTitle)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
        .frame(height: Layout.headerHeight)
    }

    func amountRow(_ content: MultichainSwapAmountCardContent) -> some View {
        HStack(alignment: .center, spacing: Layout.amountRowSpacing) {
            if content.showsQuoteShimmer {
                ShimmerSwiftUIView(config: shimmerCapsuleConfig)
                    .frame(
                        width: Layout.quoteShimmerAmountWidth,
                        height: Layout.quoteShimmerAmountHeight
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Layout.quoteShimmerAmountTopPadding)
            } else if let quoteUnavailableText = content.quoteUnavailableText {
                Text(quoteUnavailableText)
                    .font(Font(TKTextStyle.num2.font))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(Layout.amountMinimumScaleFactor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Layout.amountInputTopPadding)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Layout.amountInputSpacing) {
                    if let amountPrefix = content.amountPrefix {
                        Text(amountPrefix)
                            .font(Font(TKTextStyle.num2.font))
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                    }
                    amountTextField(content)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Layout.amountInputTopPadding)
            }

            MultichainSwapTokenPickerCapsule(
                imageSource: content.tokenAvatarSource,
                symbol: content.tokenSymbol,
                accessibilityIdentifier: accessibilityIdentifier(
                    for: content.field,
                    suffix: "token"
                ),
                action: content.onTapToken
            )
            .padding(.top, Layout.tokenTopPadding)
        }
    }

    func footerView(_ content: MultichainSwapAmountCardContent) -> some View {
        HStack(alignment: .center, spacing: Layout.footerSpacing) {
            if content.showsQuoteShimmer {
                shimmerBlock(
                    width: Layout.shimmerFooterLeadingWidth,
                    height: Layout.shimmerLineHeight
                )
            } else if let rateText = content.rateText {
                if let onTapRateText = content.onTapRateText {
                    Button(action: onTapRateText) {
                        rateTextView(rateText, showsToggleIcon: content.showsRateToggleIcon)
                    }
                    .buttonStyle(TKTapAnimationButtonStyle())
                    .accessibilityIdentifier(accessibilityIdentifier(
                        for: content.field,
                        suffix: "amount_mode"
                    ))
                } else {
                    rateTextView(rateText, showsToggleIcon: content.showsRateToggleIcon)
                }
            }

            Spacer(minLength: Layout.footerSpacerMinLength)

            if content.balanceText != nil || (content.field == .send && content.maxTitle != nil) {
                HStack(spacing: Layout.footerTextSpacing) {
                    if let insufficientBalance = content.insufficientBalance {
                        Text(insufficientBalance)
                            .textStyle(.body2)
                            .foregroundStyle(.accentRed)
                            .lineLimit(1)
                    } else if let balanceText = content.balanceText {
                        Text(balanceText)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                    }
                    if content.field == .send, let maxTitle = content.maxTitle {
                        Button(action: content.onTapMax) {
                            Text(maxTitle)
                                .textStyle(.label2)
                                .foregroundStyle(.accentBlue)
                                .lineLimit(1)
                        }
                        .buttonStyle(TKTapAnimationButtonStyle())
                    }
                }
                // The rate text gives way first, so a long fiat value never truncates
                // or shifts the balance/error text.
                .layoutPriority(1)
            }
        }
        .frame(height: Layout.footerHeight)
    }

    func amountTextField(_ content: MultichainSwapAmountCardContent) -> some View {
        TextField("0", text: content.amount)
            .font(Font(TKTextStyle.num2.font))
            .foregroundStyle(.textPrimary)
            .tint(.accentBlue)
            .keyboardType(.decimalPad)
            .autocorrectionDisabled()
            .lineLimit(1)
            .focused(content.focusedField, equals: content.field)
            .disabled(!isAmountEditable(content))
            .opacity(content.amountState == .loading ? 0 : 1)
            .overlay(alignment: .leading) {
                if content.amountState == .loading {
                    amountTextShimmer(content)
                }
            }
            .accessibilityIdentifier(accessibilityIdentifier(
                for: content.field,
                suffix: "amount"
            ))
            .onAppear {
                lastAmount = content.amount.wrappedValue
            }
            .onChange(of: content.amount.wrappedValue) { newValue in
                // Backspacing the auto inserted separator away must not re-add it.
                let isDeleting = newValue.count < lastAmount.count && lastAmount.hasPrefix(newValue)
                let normalized = MultichainSwapAmountCard.normalizeDecimalInput(
                    newValue,
                    maximumFractionDigits: content.maximumFractionDigits,
                    decimalSeparator: content.decimalSeparator,
                    interpretsLeadingZeroAsFractionalShortcut: !isDeleting
                )
                lastAmount = normalized
                if normalized != newValue {
                    content.amount.wrappedValue = normalized
                }
            }
    }

    func accessibilityIdentifier(
        for field: MultichainSwapAmountField,
        suffix: String
    ) -> String {
        switch field {
        case .send:
            return "swap_send_\(suffix)"
        case .receive:
            return "swap_receive_\(suffix)"
        }
    }

    func amountTextShimmer(_ content: MultichainSwapAmountCardContent) -> some View {
        let amountText = content.amount.wrappedValue.isEmpty ? "0" : content.amount.wrappedValue
        return MultichainSwapAmountTextShimmer(text: amountText)
            .allowsHitTesting(false)
    }

    func rateTextView(_ rateText: String, showsToggleIcon: Bool) -> some View {
        HStack(spacing: Layout.rateTextSpacing) {
            Text(rateText)
                .textStyle(.body2)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)

            if showsToggleIcon {
                SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size16.swapVertical)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.rateIconSize, height: Layout.rateIconSize)
                    .foregroundStyle(.iconTertiary)
            }
        }
    }

    func shimmerBlock(width: CGFloat, height: CGFloat) -> some View {
        ShimmerSwiftUIView(config: shimmerConfig)
            .frame(width: width, height: height)
    }

    var shimmerConfig: ShimmerSwiftUIView.Config {
        .init(
            color: .backgroundContentTint,
            cornerRadius: .capsule
        )
    }

    var shimmerCapsuleConfig: ShimmerSwiftUIView.Config {
        .init(
            color: .backgroundContentTint,
            cornerRadius: .capsule
        )
    }

    func isFocused(content: MultichainSwapAmountCardContent) -> Bool {
        guard content.amountState == .editable else {
            return false
        }
        let focus = content.focusedField.wrappedValue
        if focus == nil {
            return content.field == .send
        }
        return focus == content.field
    }

    func fieldBackgroundColor(for content: MultichainSwapAmountCardContent) -> TKColor {
        MultichainSwapAmountCardColors.background(for: fieldState(for: content))
    }

    func fieldBorderColor(for content: MultichainSwapAmountCardContent) -> TKColor {
        MultichainSwapAmountCardColors.border(for: fieldState(for: content))
    }

    func fieldState(for content: MultichainSwapAmountCardContent) -> TKTextFieldState {
        isFocused(content: content) ? .active : .inactive
    }

    func isAmountEditable(_ content: MultichainSwapAmountCardContent) -> Bool {
        content.amountState == .editable && content.field == .send
    }

    enum Layout {
        static let amountInputSpacing: CGFloat = 2
        static let amountInputTopPadding: CGFloat = 6
        static let amountMinimumScaleFactor: CGFloat = 0.5
        static let amountFooterSpacing: CGFloat = 10
        static let amountFooterShimmerSpacing: CGFloat = 9
        static let amountRowSpacing: CGFloat = 12
        static let borderWidth: CGFloat = 1.5
        static let cardCornerRadius: CGFloat = 16
        static let sendCardHeight: CGFloat = 126
        static let receiveCardHeight: CGFloat = 122
        static let footerBottomPadding: CGFloat = 12
        static let footerHeight: CGFloat = 20
        static let footerSpacerMinLength: CGFloat = 8
        static let footerSpacing: CGFloat = 8
        static let footerTextSpacing: CGFloat = 8
        static let headerHeight: CGFloat = 20
        static let headerSpacing: CGFloat = 4
        static let headerTopPadding: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let rateIconSize: CGFloat = 16
        static let rateTextSpacing: CGFloat = 4
        static let quoteShimmerAmountHeight: CGFloat = 36
        static let quoteShimmerAmountTopPadding: CGFloat = 9
        static let quoteShimmerAmountWidth: CGFloat = 104
        static let shimmerAmountTopPadding: CGFloat = 14
        static let shimmerFooterLeadingWidth: CGFloat = 45
        static let shimmerFooterTopPadding: CGFloat = 9
        static let shimmerFooterTrailingWidth: CGFloat = 142
        static let shimmerHeaderWidth: CGFloat = 80
        static let shimmerLineHeight: CGFloat = 12
        static let shimmerTokenHeight: CGFloat = 40
        static let shimmerTokenTopPadding: CGFloat = 12
        static let shimmerTokenWidth: CGFloat = 104
        static let tokenTopPadding: CGFloat = 4
        static let zeroSpacing: CGFloat = 0
    }
}

extension MultichainSwapAmountCard {
    static func normalizeDecimalInput(
        _ raw: String,
        maximumFractionDigits: Int? = nil,
        decimalSeparator: String = ".",
        interpretsLeadingZeroAsFractionalShortcut: Bool = true
    ) -> String {
        let separator = decimalSeparator.isEmpty ? "." : decimalSeparator
        var integer = ""
        var fraction = ""
        var hasDecimalSeparator = false

        for character in raw where character.isASCII {
            if character.isNumber {
                if hasDecimalSeparator {
                    if let maximumFractionDigits, fraction.count >= maximumFractionDigits {
                        continue
                    }
                    fraction.append(character)
                } else {
                    integer.append(character)
                }
            } else if character == "." || character == "," {
                guard maximumFractionDigits != 0, !hasDecimalSeparator else {
                    continue
                }
                hasDecimalSeparator = true
            }
        }

        guard !integer.isEmpty || hasDecimalSeparator else {
            return ""
        }

        if hasDecimalSeparator {
            return (integer.isEmpty ? "0" : integer) + separator + fraction
        }
        guard interpretsLeadingZeroAsFractionalShortcut,
              maximumFractionDigits != 0,
              integer.first == "0"
        else {
            return integer
        }
        let shortcutFraction = String(integer.dropFirst())
        return "0" + separator + (maximumFractionDigits.map { String(shortcutFraction.prefix($0)) } ?? shortcutFraction)
    }
}

enum MultichainSwapAmountCardColors {
    static func background(for state: TKTextFieldState) -> TKColor {
        switch state {
        case .inactive:
            .backgroundContent
        case .active:
            .fieldBackground
        case .error:
            .fieldErrorBackground
        }
    }

    static func border(for state: TKTextFieldState) -> TKColor {
        switch state {
        case .inactive:
            .clear
        case .active:
            .fieldActiveBorder
        case .error:
            .fieldErrorBorder
        }
    }
}

private struct MultichainSwapAmountTextShimmer: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Font(TKTextStyle.num2.font))
            .lineLimit(1)
            .foregroundStyle(.textTertiary)
            .tkTextShimmer(isActive: true)
    }
}

#Preview {
    MultichainSwapAmountCardPreview()
        .tkThemed()
}

private struct MultichainSwapAmountCardPreview: View {
    @State private var sendAmount = "0"
    @State private var fiatAmount = "42.70"
    @State private var receiveAmount = "42.7"
    @FocusState private var focusedField: MultichainSwapAmountField?

    var body: some View {
        VStack(spacing: PreviewLayout.cardSpacing) {
            MultichainSwapAmountCard(
                config: .content(
                    MultichainSwapAmountCardContent(
                        amount: $sendAmount,
                        balanceText: "Balance: 2 345",
                        rateText: "$ 0.00",
                        maximumFractionDigits: 18,
                        field: .send,
                        focusedField: $focusedField,
                        tokenAvatarSource: .image(.TKUIKit.Icons.Size96.tonIcon, chainIcon: .TKUIKit.Icons.Size20.ethChain),
                        tokenSymbol: "TON",
                        network: "Ethereum",
                        maxTitle: "MAX",
                        onTapCard: {
                            focusedField = .send
                        },
                        onTapMax: {
                            sendAmount = "12.45"
                        },
                        onTapToken: {}
                    )
                )
            )

            MultichainSwapAmountCard(
                config: .content(
                    MultichainSwapAmountCardContent(
                        amount: $sendAmount,
                        insufficientBalance: "Insufficient balance",
                        balanceText: "Balance: 2 345",
                        rateText: "$ 0.00",
                        maximumFractionDigits: 18,
                        field: .send,
                        focusedField: $focusedField,
                        tokenAvatarSource: .image(.TKUIKit.Icons.Size96.tonIcon, chainIcon: .TKUIKit.Icons.Size20.ethChain),
                        tokenSymbol: "TON",
                        network: "Ethereum",
                        maxTitle: "MAX",
                        onTapCard: {
                            focusedField = .send
                        },
                        onTapMax: {
                            sendAmount = "12.45"
                        },
                        onTapToken: {}
                    )
                )
            )

            MultichainSwapAmountCard(
                config: .content(
                    MultichainSwapAmountCardContent(
                        amount: $fiatAmount,
                        balanceText: "Balance: 12.45 ETH",
                        rateText: "0.012 ETH",
                        maximumFractionDigits: 2,
                        field: .send,
                        focusedField: $focusedField,
                        tokenAvatarSource: .image(.TKUIKit.Icons.Size96.tonIcon, chainIcon: .TKUIKit.Icons.Size20.ethChain),
                        tokenSymbol: "ETH\n😭😭😭😭😭😭",
                        network: "Ethereum",
                        maxTitle: "Max",
                        onTapCard: {
                            focusedField = .send
                        },
                        onTapMax: {},
                        onTapRateText: {},
                        onTapToken: {}
                    )
                )
            )

            MultichainSwapAmountCard(
                amount: $receiveAmount,
                balanceText: nil,
                field: .receive,
                focusedField: $focusedField,
                tokenAvatarSource: .image(.TKUIKit.Icons.Size96.tonIcon, chainIcon: .TKUIKit.Icons.Size20.ethChain),
                tokenSymbol: "TON",
                network: "TON",
                onTapCard: {
                    focusedField = .receive
                },
                onTapMax: {},
                onTapToken: {}
            )

            MultichainSwapAmountCard(
                config: .shimmer(.receive)
            )
        }
        .padding(.horizontal, PreviewLayout.horizontalPadding)
        .padding(.vertical, PreviewLayout.verticalPadding)
        .onAppear {
            focusedField = .send
        }
        .debugPreview(background: .page)
    }

    private enum PreviewLayout {
        static let cardSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 24
    }
}
