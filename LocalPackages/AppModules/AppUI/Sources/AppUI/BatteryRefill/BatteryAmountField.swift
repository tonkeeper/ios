import SwiftUI
import TKUIKit

/// The manual top-up amount on the Battery screen: the field and the line under it.
public struct BatteryAmountField: View {
    private let placeholder: String
    private let text: Binding<String>
    private let caption: String
    private let isValid: Bool
    private let isFocused: FocusState<Bool>.Binding
    private let accessibilityIdentifier: String
    @State private var proposedText: String?

    public init(
        placeholder: String,
        text: Binding<String>,
        caption: String,
        isValid: Bool,
        isFocused: FocusState<Bool>.Binding,
        accessibilityIdentifier: String
    ) {
        self.placeholder = placeholder
        self.text = text
        self.caption = caption
        self.isValid = isValid
        self.isFocused = isFocused
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TKInputField(placeholder: placeholder, text: shownText, isValid: isValid, isFocused: isFocused)
                .tkNumPadKeyboard()
                .accessibilityIdentifier(accessibilityIdentifier)
                .onChange(of: proposedText) { value in
                    if value != nil { proposedText = nil }
                }
            Text(caption)
                .textStyle(.body2)
                .foregroundStyle(isValid ? TKColor.textSecondary : .accentRed)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Layout.captionTopPadding)
                .padding(.horizontal, Layout.captionHorizontalPadding)
        }
    }

    private var shownText: Binding<String> {
        Binding(
            get: { proposedText ?? text.wrappedValue },
            set: {
                proposedText = $0
                if let amount = TKAmountDigits.normalized($0) {
                    text.wrappedValue = amount
                }
            }
        )
    }

    private enum Layout {
        static let captionTopPadding: CGFloat = 12
        static let captionHorizontalPadding: CGFloat = 16
    }
}
