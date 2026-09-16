public struct MultichainSwapViewActions {
    public let close: () -> Void
    public let retryLoading: () -> Void
    public let openRaffle: () -> Void
    public let updateSendAmount: (String) -> Void
    public let applyMaxSend: () -> Void
    public let toggleSendAmountInputMode: () -> Void
    public let requestPickSendToken: () -> Void
    public let toggleReceiveAmountInputMode: () -> Void
    public let requestPickReceiveToken: () -> Void
    public let swapTokens: () -> Void
    public let toggleRateDisplayDirection: () -> Void
    public let notifyQuoteRefreshCompleted: () -> Void
    public let continueSwap: () -> Void

    public init(
        close: @escaping () -> Void,
        retryLoading: @escaping () -> Void,
        openRaffle: @escaping () -> Void,
        updateSendAmount: @escaping (String) -> Void,
        applyMaxSend: @escaping () -> Void,
        toggleSendAmountInputMode: @escaping () -> Void,
        requestPickSendToken: @escaping () -> Void,
        toggleReceiveAmountInputMode: @escaping () -> Void,
        requestPickReceiveToken: @escaping () -> Void,
        swapTokens: @escaping () -> Void,
        toggleRateDisplayDirection: @escaping () -> Void,
        notifyQuoteRefreshCompleted: @escaping () -> Void,
        continueSwap: @escaping () -> Void
    ) {
        self.close = close
        self.retryLoading = retryLoading
        self.openRaffle = openRaffle
        self.updateSendAmount = updateSendAmount
        self.applyMaxSend = applyMaxSend
        self.toggleSendAmountInputMode = toggleSendAmountInputMode
        self.requestPickSendToken = requestPickSendToken
        self.toggleReceiveAmountInputMode = toggleReceiveAmountInputMode
        self.requestPickReceiveToken = requestPickReceiveToken
        self.swapTokens = swapTokens
        self.toggleRateDisplayDirection = toggleRateDisplayDirection
        self.notifyQuoteRefreshCompleted = notifyQuoteRefreshCompleted
        self.continueSwap = continueSwap
    }
}
