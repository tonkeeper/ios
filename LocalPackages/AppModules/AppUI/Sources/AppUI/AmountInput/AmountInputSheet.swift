import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

/// The amount card every "enter amount" screen shares: the typed value with its unit, the
/// converted value that switches the input unit, and the balance row with Max.
public struct AmountInputSheetState {
    public enum Symbol {
        case icon(UIImage)
        case text(String)
    }

    public struct Converted {
        public var text: String
        public var symbol: Symbol?
        public var showsSwitchIcon: Bool
        public var isSwitchEnabled: Bool
        public var isLoading: Bool
        /// The content stays in place and shimmers, unlike `isLoading`, which swaps the whole pill for a capsule.
        public var isTextLoading: Bool
        public var showsChevron: Bool
        public var leadingImage: UIImage?
        public var leadingImageURL: URL?
        /// The network badge on the asset icon, such as TON on USDT (TON).
        public var leadingChainImage: UIImage?
        /// The amount in white with a larger asset icon and the switch icon for the picker, as Buy
        /// crypto's design shows what is received.
        public var highlightsAmount: Bool

        public init(
            text: String,
            symbol: Symbol? = nil,
            showsSwitchIcon: Bool,
            isSwitchEnabled: Bool,
            isLoading: Bool = false,
            isTextLoading: Bool = false,
            showsChevron: Bool = false,
            leadingImage: UIImage? = nil,
            leadingImageURL: URL? = nil,
            leadingChainImage: UIImage? = nil,
            highlightsAmount: Bool = false
        ) {
            self.text = text
            self.symbol = symbol
            self.showsSwitchIcon = showsSwitchIcon
            self.isSwitchEnabled = isSwitchEnabled
            self.isLoading = isLoading
            self.isTextLoading = isTextLoading
            self.showsChevron = showsChevron
            self.leadingImage = leadingImage
            self.leadingImageURL = leadingImageURL
            self.leadingChainImage = leadingChainImage
            self.highlightsAmount = highlightsAmount
        }
    }

    public struct QuickOption: Identifiable {
        public var id: String
        public var title: String
        public var isSelected: Bool

        public init(id: String, title: String, isSelected: Bool) {
            self.id = id
            self.title = title
            self.isSelected = isSelected
        }
    }

    public struct Balance {
        public var text: String
        public var isLoading: Bool
        public var isError: Bool
        public var showsMax: Bool
        public var isMaxEnabled: Bool
        public var isMaxSelected: Bool
        public var maxHint: String?
        public var errorHint: String?
        public var actionTitle: String?

        public init(
            text: String,
            isLoading: Bool = false,
            isError: Bool = false,
            showsMax: Bool,
            isMaxEnabled: Bool = true,
            isMaxSelected: Bool = false,
            maxHint: String? = nil,
            errorHint: String? = nil,
            actionTitle: String? = nil
        ) {
            self.text = text
            self.isLoading = isLoading
            self.isError = isError
            self.showsMax = showsMax
            self.isMaxEnabled = isMaxEnabled
            self.isMaxSelected = isMaxSelected
            self.maxHint = maxHint
            self.errorHint = errorHint
            self.actionTitle = actionTitle
        }
    }

    public var text: String
    public var placeholder: String
    /// The value is on its way, as a Max still being priced: the typed row shimmers until it lands.
    public var isTextLoading: Bool
    /// The value is out of the limits: it is drawn in red, its cursor too.
    public var isTextError: Bool = false
    /// Drawn before the value, e.g. "$" while typing in dollars.
    public var prefix: String?
    public var symbol: Symbol?
    public var converted: Converted?
    public var quickOptions: [QuickOption]
    /// The options are being recalculated: capsules of the same size shimmer in their place.
    public var isQuickOptionsLoading: Bool
    public var balance: Balance?
    public var textFieldAccessibilityIdentifier: String?

    public init(
        text: String,
        placeholder: String = "0",
        isTextLoading: Bool = false,
        prefix: String? = nil,
        symbol: Symbol?,
        converted: Converted?,
        quickOptions: [QuickOption] = [],
        isQuickOptionsLoading: Bool = false,
        balance: Balance?,
        textFieldAccessibilityIdentifier: String? = nil
    ) {
        self.text = text
        self.placeholder = placeholder
        self.isTextLoading = isTextLoading
        self.prefix = prefix
        self.symbol = symbol
        self.converted = converted
        self.quickOptions = quickOptions
        self.isQuickOptionsLoading = isQuickOptionsLoading
        self.balance = balance
        self.textFieldAccessibilityIdentifier = textFieldAccessibilityIdentifier
    }
}

public struct AmountInputSheet: View {
    @State private var proposedText: String?

    private let cardHeight: CGFloat?
    private let state: AmountInputSheetState
    private let focus: FocusState<Bool>.Binding
    private let onTextChange: (String) -> Void
    private let onToggle: () -> Void
    private let onMax: () -> Void
    private let onConvertedTap: () -> Void
    private let onQuickOption: (String) -> Void
    private let onBalanceAction: () -> Void

    /// `cardHeight` replaces the card's base height; quick options and the balance row still add theirs.
    public init(
        cardHeight: CGFloat? = nil,
        state: AmountInputSheetState,
        focus: FocusState<Bool>.Binding,
        onTextChange: @escaping (String) -> Void,
        onToggle: @escaping () -> Void,
        onMax: @escaping () -> Void,
        onConvertedTap: @escaping () -> Void = {},
        onQuickOption: @escaping (String) -> Void = { _ in },
        onBalanceAction: @escaping () -> Void = {}
    ) {
        self.cardHeight = cardHeight
        self.state = state
        self.focus = focus
        self.onTextChange = onTextChange
        self.onToggle = onToggle
        self.onMax = onMax
        self.onConvertedTap = onConvertedTap
        self.onQuickOption = onQuickOption
        self.onBalanceAction = onBalanceAction
    }

    /// The card's height with and without the balance row, for UIKit hosts that size it by a constraint.
    public static func height(showsBalance: Bool, showsQuickOptions: Bool = false, cardHeight: CGFloat? = nil) -> CGFloat {
        (cardHeight ?? Layout.cardHeight)
            + (showsQuickOptions ? Layout.quickOptionsBlockHeight : 0)
            + (showsBalance ? Layout.balanceHeight : 0)
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Layout.valueSpacing) {
                inputRow
                convertedButton
                if !state.quickOptions.isEmpty {
                    quickOptionsRow
                        .padding(.top, Layout.quickOptionsTopSpacing - Layout.valueSpacing)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.height(showsBalance: false, showsQuickOptions: !state.quickOptions.isEmpty, cardHeight: cardHeight))
            .background(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                    .fill(.backgroundContent)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                focus.wrappedValue = true
            }

            if let balance = state.balance {
                balanceRow(balance)
                    .frame(height: Layout.balanceHeight)
            }
        }
    }
}

private extension AmountInputSheet {
    var inputRow: some View {
        GeometryReader { proxy in
            HStack(spacing: Layout.symbolSpacing) {
                HStack(spacing: Layout.prefixSpacing) {
                    if let prefix = state.prefix {
                        Text(prefix)
                            .font(Font(Layout.inputFont))
                            .foregroundStyle(.textSecondary)
                    }
                    TKNumPadTextField(
                        state.placeholder,
                        text: Binding(
                            get: { proposedText ?? state.text },
                            set: {
                                proposedText = $0
                                onTextChange($0)
                            }
                        ),
                        font: Layout.inputFont,
                        color: state.isTextError ? .accentRed : .textPrimary,
                        alignment: state.prefix == nil ? .trailing : .leading
                    )
                    .tint(state.isTextError ? .accentRed : .accentBlue)
                    .autocorrectionDisabled()
                    .lineLimit(1)
                    .focused(focus)
                    // Reset rejected edits even when the model's value stays unchanged.
                    .onChange(of: proposedText) { value in
                        if value != nil { proposedText = nil }
                    }
                    .accessibilityIdentifier(state.textFieldAccessibilityIdentifier ?? "")
                    .frame(width: inputTextWidth(availableWidth: proxy.size.width))
                }

                if let symbol = state.symbol {
                    inputSymbolView(symbol)
                }
            }
            .animation(TKNumPadTextField.layoutAnimation, value: state.text)
            .tkTextShimmer(isActive: state.isTextLoading, dimmingInto: .backgroundContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Layout.inputRowHeight)
    }

    func inputTextWidth(availableWidth: CGFloat) -> CGFloat {
        let displayText = state.text.isEmpty ? state.placeholder : TKNumPadTextField.displayText(state.text)
        let symbolWidth: CGFloat = switch state.symbol {
        case .icon: Layout.inputSymbolIconSize.width + Layout.symbolSpacing
        case let .text(symbol): textWidth(symbol, font: TKTextStyle.num2.font) + Layout.symbolSpacing
        case nil: 0
        }
        let prefixWidth = state.prefix.map { textWidth($0, font: Layout.inputFont) + Layout.prefixSpacing } ?? 0
        let available = max(
            Layout.inputMinimumWidth,
            availableWidth - Layout.inputHorizontalMargin * 2 - symbolWidth - prefixWidth
        )
        let width = min(available, textWidth(displayText, font: Layout.inputFont) + Layout.caretPadding)
        return max(width, Layout.inputMinimumWidth)
    }

    func textWidth(_ string: String, font: UIFont) -> CGFloat {
        ceil((string as NSString).size(withAttributes: [.font: font]).width)
    }

    @ViewBuilder
    func inputSymbolView(_ symbol: AmountInputSheetState.Symbol) -> some View {
        switch symbol {
        case let .icon(image):
            SwiftUI.Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.iconSecondary)
                .frame(width: Layout.inputSymbolIconSize.width, height: Layout.inputSymbolIconSize.height)
        case let .text(symbol):
            Text(symbol)
                .textStyle(.num2)
                .foregroundStyle(.textSecondary)
                .offset(y: Layout.inputSymbolTextOffset)
        }
    }

    @ViewBuilder
    var convertedButton: some View {
        if let converted = state.converted, converted.isLoading, converted.highlightsAmount {
            // Buy crypto's skeleton: the pill's place, without its border, still opening the picker.
            Button(action: converted.showsChevron ? onConvertedTap : onToggle) {
                ShimmerSwiftUIView(config: .init(color: .backgroundContentTint, cornerRadius: .capsule))
                    .frame(width: Layout.highlightedShimmerSize.width, height: Layout.highlightedShimmerSize.height)
                    .padding(.vertical, Layout.highlightedShimmerVerticalInset)
            }
            .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
            .disabled(!converted.isSwitchEnabled && !converted.showsChevron)
            .accessibilityIdentifier("amount_input_converted")
        } else if let converted = state.converted {
            Button(action: converted.showsChevron ? onConvertedTap : onToggle) {
                convertedContent(converted)
                    .padding(.vertical, Layout.convertedVerticalPadding)
                    .padding(.horizontal, Layout.convertedHorizontalPadding)
                    .background(
                        Capsule(style: .continuous)
                            .strokeBorder(.buttonTertiaryBackground, lineWidth: Layout.convertedBorderWidth)
                    )
            }
            .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
            .disabled(!converted.isSwitchEnabled && !converted.showsChevron)
            .accessibilityIdentifier("amount_input_converted")
        }
    }

    var quickOptionsRow: some View {
        HStack(spacing: Layout.quickOptionsSpacing) {
            ForEach(state.quickOptions) { option in
                if state.isQuickOptionsLoading {
                    ShimmerSwiftUIView(config: .init(color: .buttonTertiaryBackground, cornerRadius: .capsule))
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.quickOptionHeight)
                } else {
                    Button {
                        onQuickOption(option.id)
                    } label: {
                        Text(option.title)
                            .textStyle(.label2)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .frame(height: Layout.quickOptionHeight)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(option.isSelected ? TKColor.buttonSecondaryBackground : TKColor.buttonTertiaryBackground)
                            )
                    }
                    .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
                }
            }
        }
        .padding(.horizontal, Layout.quickOptionsHorizontalPadding)
    }

    @ViewBuilder
    func convertedContent(_ converted: AmountInputSheetState.Converted) -> some View {
        if converted.isLoading {
            ShimmerSwiftUIView(config: .init(color: .backgroundContentTint, cornerRadius: .capsule))
                .frame(width: Layout.convertedShimmerSize.width, height: Layout.convertedShimmerSize.height)
        } else {
            HStack(spacing: Layout.symbolSpacing) {
                convertedLeadingIcon(converted)
                    .padding(.trailing, converted.highlightsAmount ? Layout.highlightedIconTrailingPadding : 0)

                Text(converted.text)
                    .textStyle(.body1)
                    .foregroundStyle(converted.highlightsAmount ? .textPrimary : .textSecondary)
                    .lineLimit(1)

                switch converted.symbol {
                case let .icon(image):
                    SwiftUI.Image(uiImage: image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.iconSecondary)
                        .frame(width: Layout.convertedIconSize, height: Layout.convertedIconSize)
                case let .text(symbol):
                    Text(symbol)
                        .textStyle(.body1)
                        .foregroundStyle(.textSecondary)
                case nil:
                    EmptyView()
                }

                if converted.showsChevron {
                    // Buy crypto's design opens its asset picker with the switch icon.
                    (converted.highlightsAmount ? SwiftUI.Image.TKUIKit.Icons.Size16.switch : SwiftUI.Image.TKUIKit.Icons.Size16.chevronDown)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Layout.convertedIconSize, height: Layout.convertedIconSize)
                        .foregroundStyle(.iconSecondary)
                        // The design's 4 pt from the ticker is the row's own spacing.
                        .padding(.leading, converted.highlightsAmount ? 0 : Layout.switchIconLeadingPadding)
                } else if converted.showsSwitchIcon {
                    SwiftUI.Image.TKUIKit.Icons.Size16.switch
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Layout.convertedIconSize, height: Layout.convertedIconSize)
                        .foregroundStyle(.iconSecondary)
                        .padding(.leading, Layout.switchIconLeadingPadding)
                }
            }
            .tkTextShimmer(isActive: converted.isTextLoading)
        }
    }

    @ViewBuilder
    func convertedLeadingIcon(_ converted: AmountInputSheetState.Converted) -> some View {
        let size = converted.highlightsAmount ? Layout.highlightedIconSize : Layout.convertedIconSize
        let chainImage = converted.highlightsAmount ? converted.leadingChainImage : nil
        let configuration = AssetAvatarView.Configuration(
            imageSize: size,
            chainIconSize: chainImage == nil ? 0 : Layout.chainIconSize,
            chainIconPadding: chainImage == nil ? 0 : Layout.chainIconBorder,
            chainIconOffsetX: chainImage == nil ? 0 : Layout.chainIconOffset,
            chainIconOffsetY: chainImage == nil ? 0 : Layout.chainIconOffset
        )
        if let image = converted.leadingImage, chainImage == nil {
            SwiftUI.Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let image = converted.leadingImage {
            AssetAvatarView(imageSource: .image(image, chainIcon: chainImage), configuration: configuration, shape: .circle)
        } else if let url = converted.leadingImageURL {
            AssetAvatarView(imageSource: .url(url, chainIcon: chainImage), configuration: configuration, shape: .circle)
        }
    }

    func balanceRow(_ balance: AmountInputSheetState.Balance) -> some View {
        HStack(spacing: 0) {
            if balance.showsMax {
                maxButton(balance)
            }

            Spacer(minLength: 0)

            if balance.isLoading {
                EmptyView()
            } else if balance.isError, let errorHint = balance.errorHint {
                HintButton(configuration: Self.balanceHintConfiguration) { direction in
                    TKHintTextView(text: errorHint, position: direction)
                } label: {
                    HStack(spacing: Layout.errorIconSpacing) {
                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.exclamationMarkCircle)
                            .renderingMode(.template)
                            .foregroundStyle(.accentRed)
                        balanceText(balance)
                    }
                }
            } else {
                balanceText(balance)
            }

            if let actionTitle = balance.actionTitle {
                if !balance.isLoading, !balance.text.isEmpty {
                    Text(" · ")
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                }
                Button(action: onBalanceAction) {
                    Text(actionTitle)
                        .textStyle(.body2)
                        .foregroundStyle(.accentBlue)
                        .lineLimit(1)
                        .tkTextShimmer(isActive: balance.isLoading)
                }
                .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
                .disabled(balance.isLoading)
                .fixedSize()
            }
        }
    }

    func balanceText(_ balance: AmountInputSheetState.Balance) -> some View {
        Text(balance.text)
            .textStyle(.body2)
            .foregroundStyle(balance.isError ? .accentRed : .textSecondary)
            .lineLimit(1)
    }

    @ViewBuilder
    func maxButton(_ balance: AmountInputSheetState.Balance) -> some View {
        if let hint = balance.maxHint, balance.isMaxEnabled, !balance.isLoading {
            HintButton(configuration: Self.balanceHintConfiguration, tapAction: onMax) { direction in
                TKHintTextView(text: hint, position: direction)
            } label: {
                maxLabel(balance)
            }
            .opacity(balance.isMaxEnabled ? 1 : Layout.disabledOpacity)
        } else {
            Button(action: onMax) { maxLabel(balance) }
                .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
                .disabled(!balance.isMaxEnabled || balance.isLoading)
                .opacity(balance.isMaxEnabled || balance.isLoading ? 1 : Layout.disabledOpacity)
        }
    }

    func maxLabel(_ balance: AmountInputSheetState.Balance) -> some View {
        Text(TKLocales.Common.Numbers.max)
            .textStyle(.label2)
            .foregroundStyle(balance.isMaxSelected ? .buttonPrimaryForeground : .buttonSecondaryForeground)
            .tkTextShimmer(isActive: balance.isLoading)
            .padding(.vertical, Layout.maxVerticalPadding)
            .padding(.horizontal, Layout.maxHorizontalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(balance.isMaxSelected ? TKColor.buttonPrimaryBackground : TKColor.buttonSecondaryBackground)
            )
    }

    static var balanceHintConfiguration: HintConfiguration {
        HintConfiguration(
            position: HintPosition(
                tailParameters: TKHintTextView.tailParameters,
                horizontal: .default,
                vertical: .init(absolute: 1),
                direction: .bottomLeft
            ),
            maximumWidth: 280,
            animationStyle: .bouncing
        )
    }
}

private enum Layout {
    static let errorIconSpacing: CGFloat = 4
    static let inputFont = UIFont.tkMedium(size: 40, features: .display)
    static let cardHeight: CGFloat = 188
    static let cardCornerRadius: CGFloat = 16
    static let valueSpacing: CGFloat = 8
    static let inputRowHeight: CGFloat = 70
    static let inputHorizontalMargin: CGFloat = 4
    static let inputMinimumWidth: CGFloat = 28
    static let caretPadding: CGFloat = 4
    static let inputSymbolIconSize = CGSize(width: 28, height: 36)
    static let inputSymbolTextOffset: CGFloat = 5
    static let symbolSpacing: CGFloat = 4
    static let prefixSpacing: CGFloat = 2
    static let convertedVerticalPadding: CGFloat = 6
    static let convertedHorizontalPadding: CGFloat = 16
    static let convertedBorderWidth: CGFloat = 1.5
    static let convertedIconSize: CGFloat = 16
    static let highlightedIconSize: CGFloat = 20
    static let chainIconSize: CGFloat = 10
    /// The page shows through this ring around the network badge.
    static let chainIconBorder: CGFloat = 1
    /// The badge hangs 1.67 pt past the icon's bottom-right corner, as in the design.
    static let chainIconOffset: CGFloat = 1.67
    static let highlightedShimmerSize = CGSize(width: 140, height: 32)
    /// Keeps the pill's 36 pt height, so nothing below moves when the skeleton gives way.
    static let highlightedShimmerVerticalInset: CGFloat = 2
    /// The design's 6 pt from the asset icon to the amount, past the row's 4.
    static let highlightedIconTrailingPadding: CGFloat = 2
    static let convertedShimmerSize = CGSize(width: 96, height: 24)
    static let switchIconLeadingPadding: CGFloat = 4
    static let quickOptionsTopSpacing: CGFloat = 16
    static let quickOptionsSpacing: CGFloat = 8
    static let quickOptionsHorizontalPadding: CGFloat = 16
    static let quickOptionHeight: CGFloat = 44
    static let quickOptionsBlockHeight: CGFloat = 32
    static let balanceHeight: CGFloat = 48
    static let maxVerticalPadding: CGFloat = 5
    static let maxHorizontalPadding: CGFloat = 16
    static let disabledOpacity: CGFloat = 0.48
}
