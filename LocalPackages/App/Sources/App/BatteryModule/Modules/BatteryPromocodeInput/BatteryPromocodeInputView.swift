import SwiftUI
import TKLocalize
import TKUIKit

struct BatteryPromocodeInputView: View {
    @ObservedObject var viewModel: BatteryPromocodeInputViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        TKInputField(
            placeholder: TKLocales.Battery.Refill.promocode,
            text: Binding(
                get: { viewModel.text },
                set: { viewModel.setText($0) }
            ),
            isValid: viewModel.isValid,
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
        .task {
            viewModel.start()
        }
    }
}

private extension BatteryPromocodeInputView {
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
        } else {
            switch viewModel.accessory {
            case .none:
                EmptyView()
            case .loader:
                CircularLoader(mode: .indeterminate, preset: .small)
                    .frame(width: Layout.loaderSize, height: Layout.loaderSize)
            case .success:
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.donemarkOutline)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.successIconSize, height: Layout.successIconSize)
                    .foregroundStyle(.accentGreen)
            }
        }
    }

    enum Layout {
        static let loaderSize: CGFloat = 16
        static let successIconSize: CGFloat = 28
    }
}
