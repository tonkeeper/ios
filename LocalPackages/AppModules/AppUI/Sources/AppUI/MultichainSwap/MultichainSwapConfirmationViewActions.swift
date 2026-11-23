import UIKit

public struct MultichainSwapConfirmationViewActions {
    public let confirm: () -> Void
    public let retryQuote: () -> Void
    /// Takes the row's view so the slippage menu can point at it.
    public let selectSlippage: (UIView) -> Void
    public let pickFeeMethod: () -> Void
    public let topUpBattery: () -> Void

    public init(
        confirm: @escaping () -> Void,
        retryQuote: @escaping () -> Void,
        selectSlippage: @escaping (UIView) -> Void,
        pickFeeMethod: @escaping () -> Void,
        topUpBattery: @escaping () -> Void
    ) {
        self.confirm = confirm
        self.retryQuote = retryQuote
        self.selectSlippage = selectSlippage
        self.pickFeeMethod = pickFeeMethod
        self.topUpBattery = topUpBattery
    }
}
