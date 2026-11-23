import AppUI
import SwiftUI
import TKLocalize

struct MultichainSwapViewContainer: View {
    @ObservedObject var viewModel: MultichainSwapViewModel

    private let stateMapper: MultichainSwapViewStateMapper

    init(viewModel: MultichainSwapViewModel) {
        self.viewModel = viewModel
        stateMapper = MultichainSwapViewStateMapper(amountFormatter: viewModel.amountFormatter, now: viewModel.now)
    }

    var body: some View {
        MultichainSwapView(
            state: stateMapper.map(
                state: viewModel.state,
                promoTitle: promoTitle,
                focusRequestID: viewModel.focusRequestID,
                isSwapping: viewModel.confirmationPhase == .swapping,
                sendFailure: viewModel.sendFailure
            ),
            actions: MultichainSwapViewActions(
                close: viewModel.close,
                retryLoading: viewModel.retryLoading,
                openRaffle: viewModel.openRaffle,
                updateSendAmount: viewModel.updateSendAmount,
                applySendPercent: viewModel.applySendPercent,
                toggleSendAmountInputMode: viewModel.toggleSendAmountInputMode,
                requestPickSendToken: requestPickSendToken,
                updateReceiveAmount: viewModel.updateReceiveAmount,
                toggleReceiveAmountInputMode: viewModel.toggleReceiveAmountInputMode,
                requestPickReceiveToken: requestPickReceiveToken,
                swapTokens: viewModel.swapTokens,
                openPriceImpactInfo: viewModel.openPriceImpactInfo,
                openPricingDetails: viewModel.openPricingDetails,
                openBatteryPromo: viewModel.openBatteryPromo,
                continueSwap: viewModel.continueSwap,
                topUpBattery: viewModel.topUpBattery
            )
        )
    }
}

private extension MultichainSwapViewContainer {
    var requestPickSendToken: (() -> Void)? {
        guard !viewModel.isAssetSelectionLocked else {
            return nil
        }
        return { viewModel.requestPickSendToken() }
    }

    var requestPickReceiveToken: (() -> Void)? {
        guard !viewModel.isAssetSelectionLocked else {
            return nil
        }
        return { viewModel.requestPickReceiveToken() }
    }

    var promoTitle: String? {
        guard viewModel.rafflePresentation?.shouldShowSwapPromo == true else {
            return nil
        }
        return TKLocales.MysteryRaffle.swapPromo
    }
}
