import AppUI
import SwiftUI
import TKUIKit

struct BatteryRechargeScreen: View {
    @ObservedObject var viewModel: BatteryRechargeViewModelImplementation
    let amountInputViewModel: AmountInputSwiftUIViewModel
    let promocodeViewModel: BatteryPromocodeInputViewModel
    let recipientViewModel: RecipientInputViewModel

    var body: some View {
        BatteryRechargeForm(
            state: viewModel.formState,
            onSelectPack: viewModel.selectOption,
            onSelectAsset: viewModel.openTokenPicker,
            onContinue: viewModel.tapContinue,
            onClose: viewModel.close,
            endEditing: { viewModel.endEditing?() },
            amount: {
                if viewModel.isGift {
                    AmountInputSwiftUIView(viewModel: amountInputViewModel, textFieldAccessibilityIdentifier: "battery_recharge_amount")
                } else {
                    BatteryAmountInputView(viewModel: amountInputViewModel, field: viewModel.amountField, accessibilityIdentifier: "battery_recharge_amount")
                }
            },
            promo: {
                if viewModel.showsPromocode {
                    BatteryPromocodeInputView(viewModel: promocodeViewModel)
                }
            },
            recipient: {
                if viewModel.isGift {
                    RecipientInputView(viewModel: recipientViewModel).padding(.horizontal, 16)
                }
            }
        )
    }
}
