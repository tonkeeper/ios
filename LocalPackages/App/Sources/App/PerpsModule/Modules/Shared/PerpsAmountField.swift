import SwiftUI
import TKUIKit

struct PerpsAmountField<Accessory: View>: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var prefix: String = "$"
    var suffix: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
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
                    .fixedSize()
                if let suffix, !suffix.isEmpty {
                    Text(suffix)
                        .textStyle(.num1)
                        .foregroundStyle(.textSecondary)
                }
            }
            accessory()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.verticalPadding)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }
}

private enum Layout {
    static let innerSpacing: CGFloat = 8
    static let verticalPadding: CGFloat = 40
    static let cornerRadius: CGFloat = 16
}
