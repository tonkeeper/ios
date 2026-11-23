import AppUI
import TKLocalize

@MainActor
struct MultichainSwapConfirmationViewStateMapper {
    func map(_ viewModel: MultichainSwapConfirmationViewModel) -> MultichainSwapConfirmationViewState {
        let display = viewModel.display
        return MultichainSwapConfirmationViewState(
            rateLine: display.rateLine,
            quoteProgress: quoteProgress(viewModel.quoteStatus),
            minimumReceivedLine: display.minimumReceivedLine,
            minimumReceivedFiatLine: display.minimumReceivedFiatLine,
            slippageLine: display.slippageLine,
            canSelectSlippage: viewModel.canSelectSlippage,
            networkFee: MultichainSwapConfirmationViewState.NetworkFee(
                title: display.networkFeeTitle,
                value: display.networkFeeValue,
                method: display.networkFeeMethod,
                subtitle: display.networkFeeSubtitle,
                isShortage: display.isNetworkFeeShortage,
                canPickMethod: display.canPickFeeMethod
            ),
            temporaryReserve: display.temporaryReserve.map {
                MultichainSwapConfirmationViewState.TemporaryReserve(value: $0.value, hint: $0.hint)
            },
            action: action(viewModel)
        )
    }
}

private extension MultichainSwapConfirmationViewStateMapper {
    func quoteProgress(
        _ status: MultichainSwapConfirmationQuoteStatus
    ) -> MultichainSwapConfirmationViewState.QuoteProgress {
        switch status {
        case .loading:
            return .loading
        case let .ready(cycle):
            return .countdown(startDate: cycle.startDate, duration: cycle.duration)
        case .failed:
            return .none
        }
    }

    func action(_ viewModel: MultichainSwapConfirmationViewModel) -> MultichainSwapConfirmationViewState.Action {
        if let quoteFailureMessage = viewModel.quoteFailureMessage {
            return .quoteFailed(quoteFailureMessage)
        }
        if viewModel.isRetryUnsafe {
            return .sendFailed(TKLocales.MultichainSwap.Screen.Confirm.Error.statusUnknown)
        }
        if viewModel.requiresBatteryTopUp {
            return .topUpBattery
        }
        let isLoading = viewModel.executionState == .executing || viewModel.isConfirmPending
        if viewModel.isSwapEnabled, !isLoading, viewModel.isFeeUnpaid {
            return .feeUnpaid
        }
        return .swap(isEnabled: viewModel.isSwapEnabled, isLoading: isLoading)
    }
}
