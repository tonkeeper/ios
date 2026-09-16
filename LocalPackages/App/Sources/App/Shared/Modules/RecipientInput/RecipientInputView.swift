import SwiftUI
import TKLocalize
import TKUIKit

struct RecipientInputView: View {
    @ObservedObject var viewModel: RecipientInputViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        TKInputField(
            placeholder: TKLocales.Send.Recepient.placeholder,
            text: Binding(
                get: { viewModel.text },
                set: { viewModel.setText($0) }
            ),
            isValid: viewModel.isValid,
            axis: .multiline,
            isFocused: $isFocused
        ) {
            trailingAccessory
        }
        .onChange(of: isFocused) { newValue in
            viewModel.isFocused = newValue
        }
        .onChange(of: viewModel.isFocused) { newValue in
            isFocused = newValue
        }
    }
}

private extension RecipientInputView {
    @ViewBuilder
    var trailingAccessory: some View {
        if viewModel.text.isEmpty {
            ButtonView(
                config: ButtonView.Config(
                    title: TKLocales.Actions.paste,
                    size: .small,
                    appearance: .tertiary,
                    action: viewModel.paste
                )
            )
        } else if viewModel.isResolving {
            CircularLoader(mode: .indeterminate, preset: .small)
                .frame(width: Layout.loaderSize, height: Layout.loaderSize)
        }
    }

    enum Layout {
        static let loaderSize: CGFloat = 16
    }
}
