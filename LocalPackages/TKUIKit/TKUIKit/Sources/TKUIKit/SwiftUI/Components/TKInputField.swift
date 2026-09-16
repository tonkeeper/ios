import SwiftUI

public struct TKInputField<TrailingAccessory: View>: View {
    public enum InputAxis {
        case singleLine
        case multiline
    }

    private let placeholder: String
    private let text: Binding<String>
    private let isValid: Bool
    private let axis: InputAxis
    private let showsClearButton: Bool
    private let isFocused: FocusState<Bool>.Binding
    private let trailingAccessory: TrailingAccessory

    public init(
        placeholder: String,
        text: Binding<String>,
        isValid: Bool = true,
        axis: InputAxis = .singleLine,
        showsClearButton: Bool = true,
        isFocused: FocusState<Bool>.Binding,
        @ViewBuilder trailingAccessory: () -> TrailingAccessory
    ) {
        self.placeholder = placeholder
        self.text = text
        self.isValid = isValid
        self.axis = axis
        self.showsClearButton = showsClearButton
        self.isFocused = isFocused
        self.trailingAccessory = trailingAccessory()
    }

    public var body: some View {
        HStack(spacing: Layout.accessorySpacing) {
            ZStack(alignment: .topLeading) {
                placeholderView
                inputView
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isClearButtonVisible {
                clearButton
            }

            trailingAccessory
        }
        .padding(.vertical, Layout.verticalPadding)
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(minHeight: Layout.minHeight)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: Layout.borderWidth)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused.wrappedValue = true
        }
        .animation(.easeInOut(duration: Layout.animationDuration), value: isPlaceholderFloating)
    }
}

private extension TKInputField {
    var isPlaceholderFloating: Bool {
        !text.wrappedValue.isEmpty
    }

    var isClearButtonVisible: Bool {
        showsClearButton && isFocused.wrappedValue && !text.wrappedValue.isEmpty
    }

    var fieldState: TKTextFieldState {
        if !isValid {
            return .error
        }
        if isFocused.wrappedValue {
            return .active
        }
        return .inactive
    }

    var backgroundColor: TKColor {
        switch fieldState {
        case .inactive:
            .backgroundContent
        case .active:
            .fieldBackground
        case .error:
            .fieldErrorBackground
        }
    }

    var borderColor: TKColor {
        switch fieldState {
        case .inactive:
            .clear
        case .active:
            .fieldActiveBorder
        case .error:
            .fieldErrorBorder
        }
    }

    var placeholderView: some View {
        Text(placeholder)
            .textStyle(.body1)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .scaleEffect(
                isPlaceholderFloating ? Layout.floatingPlaceholderScale : 1,
                anchor: .topLeading
            )
            .offset(y: isPlaceholderFloating ? -Layout.floatingOffset : 0)
            .allowsHitTesting(false)
    }

    var inputView: some View {
        textField
            .font(Font(TKTextStyle.body1.font))
            .foregroundStyle(.textPrimary)
            .tint(isValid ? TKColor.accentBlue : TKColor.accentRed)
            .autocorrectionDisabled()
            .focused(isFocused)
            .submitLabel(.done)
            .onSubmit {
                isFocused.wrappedValue = false
            }
            .frame(minHeight: Layout.inputMinHeight)
            .offset(y: isPlaceholderFloating ? Layout.floatingOffset : 0)
    }

    @ViewBuilder
    var textField: some View {
        switch axis {
        case .singleLine:
            TextField("", text: text)
        case .multiline:
            if #available(iOS 16.0, *) {
                TextField("", text: text, axis: .vertical)
            } else {
                TextField("", text: text)
            }
        }
    }

    var clearButton: some View {
        Button {
            text.wrappedValue = ""
        } label: {
            SwiftUI.Image.TKUIKit.Icons.Size16.xmarkCircle
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.clearIconSize, height: Layout.clearIconSize)
                .foregroundStyle(.iconSecondary)
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
    }
}

public extension TKInputField where TrailingAccessory == EmptyView {
    init(
        placeholder: String,
        text: Binding<String>,
        isValid: Bool = true,
        axis: InputAxis = .singleLine,
        showsClearButton: Bool = true,
        isFocused: FocusState<Bool>.Binding
    ) {
        self.init(
            placeholder: placeholder,
            text: text,
            isValid: isValid,
            axis: axis,
            showsClearButton: showsClearButton,
            isFocused: isFocused,
            trailingAccessory: { EmptyView() }
        )
    }
}

private enum Layout {
    static let minHeight: CGFloat = 64
    static let inputMinHeight: CGFloat = 24
    static let cornerRadius: CGFloat = 16
    static let borderWidth: CGFloat = 1.5
    static let verticalPadding: CGFloat = 20
    static let horizontalPadding: CGFloat = 16
    static let accessorySpacing: CGFloat = 8
    static let floatingPlaceholderScale: CGFloat = 0.75
    static let floatingOffset: CGFloat = 8
    static let clearIconSize: CGFloat = 16
    static let animationDuration: CGFloat = 0.2
}

#Preview {
    struct PreviewContainer: View {
        @State private var empty = ""
        @State private var filled = "PROMO2024"
        @State private var invalid = "WRONG"
        @FocusState private var focusedFirst: Bool
        @FocusState private var focusedSecond: Bool
        @FocusState private var focusedThird: Bool

        var body: some View {
            VStack(spacing: 16) {
                TKInputField(
                    placeholder: "Promo code",
                    text: $empty,
                    isFocused: $focusedFirst
                )
                TKInputField(
                    placeholder: "Promo code",
                    text: $filled,
                    isFocused: $focusedSecond
                )
                TKInputField(
                    placeholder: "Promo code",
                    text: $invalid,
                    isValid: false,
                    isFocused: $focusedThird
                )
            }
            .padding(16)
        }
    }

    return PreviewContainer()
        .debugPreview(background: .page)
        .tkThemed()
}
