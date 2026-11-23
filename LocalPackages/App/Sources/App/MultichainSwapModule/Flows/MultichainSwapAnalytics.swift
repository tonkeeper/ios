import KeeperCore
import TKCore

/// The swap funnel in the events Android sends too, so one query builds it for both platforms. The
/// events carry the campaign of the link that opened the swap.
struct MultichainSwapAnalytics {
    let analyticsProvider: AnalyticsProvider
    let wallet: Wallet
    let utm: UtmParameters

    func logOpen() {
        log(SwapOpen(type: .native, walletMode: walletMode))
    }

    func logClick(_ input: MultichainSwapConfirmationInput) {
        let userInput = input.userInput
        log(
            SwapClick(
                type: .native,
                walletMode: walletMode,
                assetFrom: userInput.sendAsset.asset.assetId,
                assetTo: userInput.receiveAsset.asset.assetId,
                isMax: userInput.isMax
            )
        )
    }

    func logConfirm(_ input: MultichainSwapConfirmationInput, feeMethod: MultichainSwapFeeMethod) {
        let userInput = input.userInput
        log(
            SwapConfirm(
                type: .native,
                walletMode: walletMode,
                assetFrom: userInput.sendAsset.asset.assetId,
                assetTo: userInput.receiveAsset.asset.assetId,
                feeAsset: FeeAsset(multichainSwapFeeMethod: feeMethod),
                providerName: input.quoteState.route.aggregator,
                isMax: userInput.isMax
            )
        )
    }

    func logSuccess(_ input: MultichainSwapConfirmationInput, feeMethod: MultichainSwapFeeMethod) {
        let userInput = input.userInput
        log(
            SwapSuccess(
                type: .native,
                walletMode: walletMode,
                assetFrom: userInput.sendAsset.asset.assetId,
                assetTo: userInput.receiveAsset.asset.assetId,
                feeAsset: FeeAsset(multichainSwapFeeMethod: feeMethod),
                providerName: input.quoteState.route.aggregator,
                isMax: userInput.isMax
            )
        )
    }

    /// `failure` is described as in the logs, the same in every device language, without the route and payload
    /// ids: they differ on every swap, so one cause would read as a new message each time.
    func logFailure(
        _ input: MultichainSwapConfirmationInput,
        feeMethod: MultichainSwapFeeMethod,
        failure: MultichainSwapExecutionFailure
    ) {
        let userInput = input.userInput
        log(
            SwapFailed(
                type: .native,
                walletMode: walletMode,
                assetFrom: userInput.sendAsset.asset.assetId,
                assetTo: userInput.receiveAsset.asset.assetId,
                feeAsset: FeeAsset(multichainSwapFeeMethod: feeMethod),
                providerName: input.quoteState.route.aggregator,
                errorMessage: failure.logDescription.replacingOccurrences(
                    of: ", (routeId|payloadId)=[^,]*",
                    with: "",
                    options: .regularExpression
                ),
                isMax: userInput.isMax
            )
        )
    }
}

private extension MultichainSwapAnalytics {
    var walletMode: WalletMode {
        WalletMode(wallet: wallet)
    }

    func log(_ event: Encodable) {
        analyticsProvider.log(event, utm: utm)
    }
}
