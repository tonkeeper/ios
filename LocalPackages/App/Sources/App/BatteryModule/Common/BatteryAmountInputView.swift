import AppUI
import SwiftUI

struct BatteryAmountInputView: View {
    struct Field {
        let placeholder: String
        let charges: String?
        let available: String?
    }

    @ObservedObject var viewModel: AmountInputSwiftUIViewModel
    let field: Field
    var accessibilityIdentifier = "battery_refill_amount"
    @FocusState private var isFocused: Bool

    var body: some View {
        BatteryAmountField(
            placeholder: field.placeholder,
            text: Binding(get: { viewModel.text }, set: viewModel.setText),
            caption: caption,
            isValid: !viewModel.balance.isError,
            isFocused: $isFocused,
            accessibilityIdentifier: accessibilityIdentifier
        )
        // A request can land before the first render, when onChange does not see it yet.
        .onAppear { focusIfRequested() }
        .onChange(of: viewModel.focusRequest) { _ in focusIfRequested() }
    }

    private var caption: String {
        guard !viewModel.balance.isError else { return viewModel.balance.text }
        return [field.charges, field.available].compactMap { $0 }.joined(separator: " · ")
    }

    private func focusIfRequested() {
        guard viewModel.focusRequest > 0 else { return }
        DispatchQueue.main.async { isFocused = true }
    }
}
