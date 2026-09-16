import AppUI
import SwiftUI
import TKLocalize

struct MultichainSwapViewContainer: View {
    @ObservedObject var viewModel: MultichainSwapViewModel

    private let stateMapper: MultichainSwapViewStateMapper

    init(viewModel: MultichainSwapViewModel) {
        self.viewModel = viewModel
        stateMapper = MultichainSwapViewStateMapper(
            amountFormatter: viewModel.amountFormatter,
            quoteRefreshDuration: viewModel.quoteRefreshDuration
        )
    }

    var body: some View {
        MultichainSwapView(
            state: stateMapper.map(
                state: viewModel.state,
                promoTitle: promoTitle,
                focusRequestID: viewModel.focusRequestID
            ),
            actions: MultichainSwapViewActions(
                close: viewModel.close,
                retryLoading: viewModel.retryLoading,
                openRaffle: viewModel.openRaffle,
                updateSendAmount: viewModel.updateSendAmount,
                applyMaxSend: viewModel.applyMaxSend,
                toggleSendAmountInputMode: viewModel.toggleSendAmountInputMode,
                requestPickSendToken: viewModel.requestPickSendToken,
                toggleReceiveAmountInputMode: viewModel.toggleReceiveAmountInputMode,
                requestPickReceiveToken: viewModel.requestPickReceiveToken,
                swapTokens: viewModel.swapTokens,
                toggleRateDisplayDirection: viewModel.toggleRateDisplayDirection,
                notifyQuoteRefreshCompleted: viewModel.notifyCircularProgressCompleted,
                continueSwap: viewModel.continueSwap
            )
        )
    }
}

private extension MultichainSwapViewContainer {
    var promoTitle: String? {
        guard viewModel.rafflePresentation?.shouldShowSwapPromo == true else {
            return nil
        }
        return TKLocales.MysteryRaffle.swapPromo
    }
}
