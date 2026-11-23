import AppUI
import SwiftUI

struct MultichainSwapConfirmationViewContainer: View {
    @ObservedObject var viewModel: MultichainSwapConfirmationViewModel

    private let stateMapper = MultichainSwapConfirmationViewStateMapper()

    var body: some View {
        MultichainSwapConfirmationView(
            state: stateMapper.map(viewModel),
            actions: MultichainSwapConfirmationViewActions(
                confirm: viewModel.confirm,
                retryQuote: viewModel.retryQuote,
                selectSlippage: viewModel.requestSlippageSelection(sourceView:),
                pickFeeMethod: viewModel.tapFeeMethod,
                topUpBattery: viewModel.topUpBattery
            )
        )
    }
}
