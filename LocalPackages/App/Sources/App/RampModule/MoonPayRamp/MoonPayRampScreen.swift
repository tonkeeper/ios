import AppUI
import SwiftUI

struct MoonPayRampScreen: View {
    @ObservedObject var viewModel: MoonPayRampViewModel
    @FocusState private var focused: Bool

    var body: some View {
        MoonPayRampView(
            state: viewModel.screenState,
            focus: $focused,
            focusesOnAppear: true,
            onTextChange: viewModel.amountViewModel.setText,
            onQuickOption: viewModel.amountViewModel.selectQuickOption,
            onConvertedTap: viewModel.amountViewModel.tapConverted,
            onCurrencyTap: viewModel.tapCurrency,
            onToggleRateDirection: viewModel.toggleRateDirection,
            onRateTimerCompleted: viewModel.completeRateTimer,
            onPaymentMethodTap: viewModel.tapPaymentMethod,
            onAction: viewModel.tapAction,
            onClose: viewModel.close
        )
    }
}
