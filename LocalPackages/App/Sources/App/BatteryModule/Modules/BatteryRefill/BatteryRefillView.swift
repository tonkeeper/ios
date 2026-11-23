import AppUI
import SwiftUI

struct BatteryRefillScreen: View {
    @ObservedObject var viewModel: BatteryRefillViewModelImplementation
    let promocodeViewModel: BatteryPromocodeInputViewModel

    var body: some View {
        BatteryRefillView(state: viewModel.state, actions: viewModel.actions) {
            BatteryAmountInputView(viewModel: viewModel.amountInputViewModel, field: viewModel.amountField)
        } promocode: {
            BatteryPromocodeInputView(viewModel: promocodeViewModel)
        }
    }
}
