public struct MultichainSwapViewActions {
    public let close: () -> Void
    public let retryLoading: () -> Void
    public let openRaffle: () -> Void
    public let updateSendAmount: (String) -> Void
    public let applySendPercent: (Int) -> Void
    public let toggleSendAmountInputMode: () -> Void
    public let requestPickSendToken: (() -> Void)?
    public let updateReceiveAmount: (String) -> Void
    public let toggleReceiveAmountInputMode: () -> Void
    public let requestPickReceiveToken: (() -> Void)?
    public let swapTokens: () -> Void
    public let openPriceImpactInfo: () -> Void
    public let openPricingDetails: () -> Void
    public let openBatteryPromo: () -> Void
    public let continueSwap: () -> Void
    public let topUpBattery: () -> Void

    public init(
        close: @escaping () -> Void,
        retryLoading: @escaping () -> Void,
        openRaffle: @escaping () -> Void,
        updateSendAmount: @escaping (String) -> Void,
        applySendPercent: @escaping (Int) -> Void,
        toggleSendAmountInputMode: @escaping () -> Void,
        requestPickSendToken: (() -> Void)?,
        updateReceiveAmount: @escaping (String) -> Void,
        toggleReceiveAmountInputMode: @escaping () -> Void,
        requestPickReceiveToken: (() -> Void)?,
        swapTokens: @escaping () -> Void,
        openPriceImpactInfo: @escaping () -> Void,
        openPricingDetails: @escaping () -> Void,
        openBatteryPromo: @escaping () -> Void,
        continueSwap: @escaping () -> Void,
        topUpBattery: @escaping () -> Void
    ) {
        self.close = close
        self.retryLoading = retryLoading
        self.openRaffle = openRaffle
        self.updateSendAmount = updateSendAmount
        self.applySendPercent = applySendPercent
        self.toggleSendAmountInputMode = toggleSendAmountInputMode
        self.requestPickSendToken = requestPickSendToken
        self.updateReceiveAmount = updateReceiveAmount
        self.toggleReceiveAmountInputMode = toggleReceiveAmountInputMode
        self.requestPickReceiveToken = requestPickReceiveToken
        self.swapTokens = swapTokens
        self.openPriceImpactInfo = openPriceImpactInfo
        self.openPricingDetails = openPricingDetails
        self.openBatteryPromo = openBatteryPromo
        self.continueSwap = continueSwap
        self.topUpBattery = topUpBattery
    }
}
