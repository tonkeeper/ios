import SwiftUI

public enum BalanceViewConfig: Hashable {
    case content(BalanceViewContent)
    case shimmer
}

public struct BalanceViewContent: Hashable {
    public struct Balance: Hashable {
        public struct Amount: Hashable {
            public struct TextPart: Hashable {
                public enum Role: Hashable {
                    case primary
                    case fraction
                }

                public var text: String
                public var role: Role

                public init(
                    text: String,
                    role: Role
                ) {
                    self.text = text
                    self.role = role
                }
            }

            public enum TextSize: Hashable {
                case regular
                case reduced
            }

            public var leadingText: String?
            public var trailingText: String?
            public var textParts: [TextPart]
            public var textSize: TextSize
            public var tooltipText: String?
            public var accessibilityText: String
            public var color: TKColor
            public var freshness: BalanceFreshness = .actual

            public init(
                leadingText: String? = nil,
                trailingText: String? = nil,
                textParts: [TextPart],
                textSize: TextSize = .regular,
                tooltipText: String? = nil,
                accessibilityText: String,
                color: TKColor = .textPrimary
            ) {
                self.leadingText = leadingText
                self.trailingText = trailingText
                self.textParts = textParts
                self.textSize = textSize
                self.tooltipText = tooltipText
                self.accessibilityText = accessibilityText
                self.color = color
            }

            public init(
                leadingText: String? = nil,
                text: String,
                color: TKColor = .textPrimary
            ) {
                self.init(
                    leadingText: leadingText,
                    textParts: [.init(text: text, role: .primary)],
                    accessibilityText: [leadingText, text]
                        .compactMap { $0 }
                        .joined(separator: " "),
                    color: color
                )
            }
        }

        public enum State: Hashable {
            case amount(Amount)
            case secure(color: TKColor)
        }

        public var state: State

        public init(
            text: String,
            color: TKColor = .textPrimary
        ) {
            self.state = .amount(Amount(text: text, color: color))
        }

        public init(amount: Amount) {
            self.state = .amount(amount)
        }

        public static func secure(color: TKColor = .textPrimary) -> Balance {
            Balance(state: .secure(color: color))
        }

        public func settingFreshness(_ freshness: BalanceFreshness) -> Balance {
            guard case var .amount(amount) = state else {
                return self
            }
            amount.freshness = freshness
            return Balance(amount: amount)
        }

        private init(state: State) {
            self.state = state
        }
    }

    public struct BackupButton: Hashable {
        public var color: TKColor

        public init(color: TKColor) {
            self.color = color
        }
    }

    public var balance: Balance
    public var address: BalanceHeaderBalanceStatusViewConfig?
    public var battery: BatterySwiftUIViewConfig?
    public var backupButton: BackupButton?
    public var amountScope: String?

    public init(
        balance: Balance,
        address: BalanceHeaderBalanceStatusViewConfig? = nil,
        battery: BatterySwiftUIViewConfig? = nil,
        backupButton: BackupButton? = nil,
        amountScope: String? = nil
    ) {
        self.balance = balance
        self.address = address
        self.battery = battery
        self.backupButton = backupButton
        self.amountScope = amountScope
    }
}

public struct BalanceSwiftUIView: View {
    public static let height: CGFloat = Layout.height

    @Environment(\.tkPalette) private var palette

    public var config: BalanceViewConfig
    private let animatesAmountUpdates: Bool
    private let balanceAction: (() -> Void)?
    private let addressAction: (() -> Void)?
    private let addressLongPressAction: (() -> Void)?
    private let batteryAction: (() -> Void)?
    private let backupAction: (() -> Void)?

    public init(
        config: BalanceViewConfig,
        animatesAmountUpdates: Bool = true,
        balanceAction: (() -> Void)? = nil,
        addressAction: (() -> Void)? = nil,
        addressLongPressAction: (() -> Void)? = nil,
        batteryAction: (() -> Void)? = nil,
        backupAction: (() -> Void)? = nil
    ) {
        self.config = config
        self.animatesAmountUpdates = animatesAmountUpdates
        self.balanceAction = balanceAction
        self.addressAction = addressAction
        self.addressLongPressAction = addressLongPressAction
        self.batteryAction = batteryAction
        self.backupAction = backupAction
    }

    public var body: some View {
        VStack(spacing: 4) {
            amountView

            addressView
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Layout.contentInsets)
        .frame(height: Layout.height, alignment: .top)
    }
}

private extension BalanceSwiftUIView {
    @ViewBuilder
    var addressView: some View {
        switch config {
        case let .content(content):
            if let address = content.address {
                BalanceHeaderBalanceStatusView(
                    config: address,
                    action: addressAction,
                    longPressAction: addressLongPressAction
                )
                .frame(height: Layout.addressHeight)
                .padding(.bottom, Layout.addressBottomPadding)
            }
        case .shimmer:
            EmptyView()
        }
    }

    var amountView: some View {
        Group {
            switch config {
            case let .content(content):
                amountContentView(content)
                    .frame(height: Layout.amountHeight)
            case .shimmer:
                ShimmerSwiftUIView(config: .init(cornerRadius: .capsule))
                    .frame(width: 220, height: 32)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    func amountContentView(_ content: BalanceViewContent) -> some View {
        HStack(alignment: .top, spacing: 0) {
            balanceActionView(content)

            HStack(alignment: .top, spacing: 10) {
                batteryContentView(content)

                backupButtonContentView(content)
            }
        }
    }

    @ViewBuilder
    func balanceActionView(_ content: BalanceViewContent) -> some View {
        switch content.balance.state {
        case let .amount(amount):
            if let tooltipText = amount.tooltipText {
                HintButton(
                    configuration: Layout.amountTooltipConfiguration,
                    doubleTapAction: balanceAction,
                    content: { position in
                        TKHintTextView(
                            text: tooltipText,
                            position: position,
                            contentInsetsModifier: {
                                $0.leading = 44
                                $0.trailing = 44
                            }
                        )
                    },
                    label: {
                        balanceContentView(content)
                    }
                )
            } else {
                button(action: balanceAction) {
                    balanceContentView(content)
                }
            }
        default:
            button(action: balanceAction) {
                balanceContentView(content)
            }
        }
    }

    @ViewBuilder
    func batteryContentView(_ content: BalanceViewContent) -> some View {
        if let battery = content.battery {
            button(action: batteryAction) {
                BatterySwiftUIView(config: battery)
                    .padding(.top, Layout.batteryTopPadding)
            }
            .padding(.leading, Layout.amountSpacing)
            .accessibilityIdentifier("wallet_battery")
        }
    }

    @ViewBuilder
    func backupButtonContentView(_ content: BalanceViewContent) -> some View {
        if let backupButton = content.backupButton {
            button(action: backupAction) {
                SwiftUI.Image.TKUIKit.Icons.Size12.informationCircle
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(backupButton.color)
                    .frame(
                        width: Layout.backupIconSide,
                        height: Layout.backupIconSide
                    )
                    .padding(Layout.backupIconPadding)
                    .background(
                        RoundedRectangle(
                            cornerRadius: Layout.backupCornerRadius,
                            style: .continuous
                        )
                        .fill(backupButton.color.opacity(Layout.backupBackgroundAlpha))
                    )
            }
            .padding(.trailing, Layout.backupTrailingPadding)
            .frame(height: Layout.amountHeight)
        }
    }

    @ViewBuilder
    func balanceContentView(_ content: BalanceViewContent) -> some View {
        switch content.balance.state {
        case let .amount(amount):
            HStack(alignment: .center, spacing: Layout.amountSpacing) {
                if let leadingText = amount.leadingText {
                    balanceText(leadingText, color: amount.color.resolve(palette), textSize: amount.textSize)
                        .fixedSize(horizontal: true, vertical: false)
                }

                amountText(amount)
                    .id(content.amountScope)

                if let trailingText = amount.trailingText {
                    balanceText(trailingText, color: amount.color.resolve(palette), textSize: amount.textSize)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .tkTextShimmer(
                isActive: amount.freshness == .pending,
                dimmingInto: .backgroundPage,
                appearsAfter: BalanceAmount.shimmerDelay,
                scope: content.amountScope
            )
            .accessibilityLabel(amount.accessibilityText)
        case let .secure(color):
            secureBalanceView(color: color.resolve(palette))
        }
    }

    @ViewBuilder
    func button<Content: View>(
        action: (() -> Void)?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let action {
            SwiftUI.Button(action: action) {
                content()
            }
            .buttonStyle(TKTapAnimationButtonStyle())
            .contentShape(Rectangle())
        } else {
            content()
        }
    }

    func balanceText(
        _ text: String,
        color: Color,
        textSize: BalanceViewContent.Balance.Amount.TextSize
    ) -> some View {
        Text(text)
            .font(Font(primaryTextStyle(textSize).font))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
            .frame(height: Layout.amountHeight)
    }

    @ViewBuilder
    func amountText(_ amount: BalanceViewContent.Balance.Amount) -> some View {
        let text = amount.textParts
            .reduce(Text("")) { result, part in
                result + Text(part.text)
                    .font(Font(textStyle(for: part.role, textSize: amount.textSize).font))
            }

        if #available(iOS 17.0, *) {
            if animatesAmountUpdates {
                formattedAmountText(text, amount: amount)
                    .contentTransition(.numericText())
                    .animation(
                        .easeInOut(duration: BalanceAmount.animationDuration),
                        value: amount.textParts
                    )
            } else {
                formattedAmountText(text, amount: amount)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }
        } else {
            formattedAmountText(text, amount: amount)
        }
    }

    func formattedAmountText(
        _ text: Text,
        amount: BalanceViewContent.Balance.Amount
    ) -> some View {
        text
            .foregroundStyle(amount.color)
            .minimumScaleFactor(Layout.amountTextMinimumScaleFactor)
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .frame(height: Layout.amountHeight)
    }

    func textStyle(
        for role: BalanceViewContent.Balance.Amount.TextPart.Role,
        textSize: BalanceViewContent.Balance.Amount.TextSize
    ) -> TKTextStyle {
        switch role {
        case .primary:
            primaryTextStyle(textSize)
        case .fraction:
            Layout.balanceFractionTextStyle
        }
    }

    func primaryTextStyle(_ textSize: BalanceViewContent.Balance.Amount.TextSize) -> TKTextStyle {
        switch textSize {
        case .regular:
            Layout.balanceTextStyle
        case .reduced:
            Layout.balanceReducedTextStyle
        }
    }

    func secureBalanceView(color: Color) -> some View {
        palette.button.secondaryBackground
            .frame(width: 76, height: 40)
            .clipShape(Capsule())
            .overlay {
                Text(Layout.secureText)
                    .textStyle(.num2)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .transformEffect(.init(translationX: 1, y: 6))
            }
            .frame(height: Layout.amountHeight, alignment: .center)
    }
}

private extension BalanceSwiftUIView {
    enum Layout {
        static let height: CGFloat = 132
        static let contentInsets = EdgeInsets(
            top: 28,
            leading: 16,
            bottom: 12,
            trailing: 16
        )
        static let amountHeight: CGFloat = 56
        static let amountSpacing: CGFloat = 8
        static let amountTextMinimumScaleFactor: CGFloat = 0.5
        static let balanceTextStyle: TKTextStyle = .balance
        static let balanceReducedTextStyle: TKTextStyle = TKTextStyle(
            font: .tkMedium(size: 38, features: .display),
            lineHeight: 56
        )
        static let balanceFractionTextStyle: TKTextStyle = TKTextStyle(
            font: .tkMedium(size: 32, features: .display),
            lineHeight: 40
        )
        static let batteryTopPadding: CGFloat = 12
        static let backupIconSide: CGFloat = 12
        static let backupIconPadding: CGFloat = 4
        static let backupCornerRadius: CGFloat = 10
        static let backupTrailingPadding: CGFloat = 10
        static let backupBackgroundAlpha: CGFloat = 0.48
        static let secureText = "* * *"
        static let addressHeight: CGFloat = TKTextStyle.body2.lineHeight
        static let addressTopPadding: CGFloat = 4
        static let addressBottomPadding: CGFloat = 8
        static let tooltipMaximumWidth: CGFloat = 280
        static let amountTooltipConfiguration = HintConfiguration(
            position: HintPosition(
                tailParameters: TKHintTextView.tailParameters,
                horizontal: .relativeToGlobal(0),
                vertical: .init(absolute: -2),
                direction: .bottomCenter
            ),
            maximumWidth: tooltipMaximumWidth,
            animationStyle: .bouncing
        )
    }
}
