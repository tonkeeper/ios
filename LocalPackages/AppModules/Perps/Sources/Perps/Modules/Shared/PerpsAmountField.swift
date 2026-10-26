import SwiftUI
import TKUIKit

public struct PerpsAmountField<Accessory: View>: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var prefix: String = "$"
    var suffix: String?
    var suffixStyle: TKTextStyle = .num1
    var suffixSpacing: CGFloat = 0
    @ViewBuilder var accessory: () -> Accessory

    public init(
        text: Binding<String>,
        focused: FocusState<Bool>.Binding,
        prefix: String = "$",
        suffix: String? = nil,
        suffixStyle: TKTextStyle = .num1,
        suffixSpacing: CGFloat = 0,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        _text = text
        self.focused = focused
        self.prefix = prefix
        self.suffix = suffix
        self.suffixStyle = suffixStyle
        self.suffixSpacing = suffixSpacing
        self.accessory = accessory
    }

    public var body: some View {
        VStack(spacing: Layout.innerSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .textStyle(.num1)
                        .foregroundStyle(.textSecondary)
                }
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .focused(focused)
                    .textStyle(.num1)
                    .foregroundStyle(.textPrimary)
                    .widthHugging(text.isEmpty ? "0" : text, style: .num1)
                if let suffix, !suffix.isEmpty {
                    Text(suffix)
                        .textStyle(suffixStyle)
                        .foregroundStyle(.textSecondary)
                        .padding(.leading, suffixSpacing)
                }
            }
            accessory()
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.verticalPadding)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }
}

extension View {
    func widthHugging(_ text: String, style: TKTextStyle) -> some View {
        Text(text)
            .textStyle(style)
            .lineLimit(1)
            .hidden()
            .overlay(self)
    }
}

private enum Layout {
    static let innerSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 40
    static let cornerRadius: CGFloat = 16
}
