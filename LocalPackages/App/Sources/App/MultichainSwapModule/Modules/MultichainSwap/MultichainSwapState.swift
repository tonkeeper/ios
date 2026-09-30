import Foundation
import KeeperCore

enum MultichainSwapQuoteState: Equatable {
    case idle
    case loading
    case ready
    case expired
    case failed
}

enum MultichainSwapValidationState: Equatable {
    case emptyAmount
    case invalidAmount
    case insufficientBalance
    case missingAddress
    case routeUnavailable
    case valid
}

enum MultichainSwapAmountInputMode: Equatable {
    case crypto
    case fiat

    var toggled: MultichainSwapAmountInputMode {
        switch self {
        case .crypto:
            return .fiat
        case .fiat:
            return .crypto
        }
    }
}

enum MultichainSwapViewModelState {
    case shimmer
    case error
    case loaded(MultichainSwapLoadedState)
}

struct MultichainSwapInputs {
    private(set) var sendAmount: String
    var sendAmountInputMode: MultichainSwapAmountInputMode
    /// The receive amount is always stored as crypto text; fiat mode only changes
    /// how the receive card renders it.
    var receiveAmount: String
    var receiveAmountInputMode: MultichainSwapAmountInputMode
    private(set) var sendAsset: MultichainAsset
    /// Set only by the Max control and cleared by every other change to the amount or the asset
    /// being sold, so a rounded fiat round trip or a provider-normalized quote cannot lose it.
    private(set) var isMaxSend: Bool
    /// Send amount rendered in the mode the send card is currently *not* in, captured at the
    /// last mode switch and dropped by every change to the amount or the asset being sold.
    /// Both conversions round, so re-deriving the text on every switch shrinks the amount a
    /// little each pass; restoring the captured one keeps a round trip exact.
    private(set) var sendAmountCounterpart: String?
    var receiveAsset: MultichainAsset
    var slippage: MultichainSwapSlippage?
    /// USD → display-currency rate derived at the initial assets load.
    let usdFiatRate: Decimal?

    init(initialAssets: MultichainSwapInitialAssets) {
        self.sendAmount = ""
        self.sendAmountInputMode = .crypto
        self.receiveAmount = ""
        self.receiveAmountInputMode = .crypto
        self.sendAsset = initialAssets.sendAsset
        self.isMaxSend = false
        self.sendAmountCounterpart = nil
        self.receiveAsset = initialAssets.receiveAsset
        self.slippage = initialAssets.slippage
        self.usdFiatRate = initialAssets.usdFiatRate
    }

    /// Crypto text the send amount stands for without re-deriving it from a rounded fiat
    /// string: the field itself in crypto mode, the counterpart captured at the last mode
    /// switch in fiat mode. `nil` once the fiat text has been edited, leaving the rounded
    /// conversion as the only source.
    var sendAmountCryptoText: String? {
        guard !sendAmount.isEmpty else {
            return nil
        }
        switch sendAmountInputMode {
        case .crypto:
            return sendAmount
        case .fiat:
            return sendAmountCounterpart
        }
    }

    func settingSendAmount(_ amount: String, isMax: Bool = false) -> MultichainSwapInputs {
        var inputs = self
        inputs.sendAmount = amount
        inputs.isMaxSend = isMax
        inputs.sendAmountCounterpart = nil
        return inputs
    }

    func settingSendAsset(_ asset: MultichainAsset) -> MultichainSwapInputs {
        var inputs = self
        inputs.sendAsset = asset
        inputs.isMaxSend = false
        inputs.sendAmountCounterpart = nil
        return inputs
    }

    /// Switches the send card's input mode, restoring the text captured for the target mode
    /// when the amount has not changed since. `isMaxSend` survives because the amount does
    /// not change here — only the currency it is written in.
    func switchingSendAmountInputMode(
        to mode: MultichainSwapAmountInputMode,
        convertedAmount: String
    ) -> MultichainSwapInputs {
        var inputs = self
        inputs.sendAmountInputMode = mode
        inputs.sendAmount = sendAmountCounterpart ?? convertedAmount
        inputs.sendAmountCounterpart = sendAmount
        return inputs
    }
}

struct MultichainSwapLoadedState {
    let sendAmount: String
    let sendAmountInputMode: MultichainSwapAmountInputMode
    /// Display text of the receive card's primary amount: crypto text in crypto
    /// mode, converted fiat text in fiat mode.
    let receiveAmount: String
    let receiveAmountInputMode: MultichainSwapAmountInputMode
    /// Currency symbols pinned as non-removable prefixes of the amount fields
    /// while the corresponding card is in fiat input mode.
    let sendAmountFiatSymbol: String?
    let receiveAmountFiatSymbol: String?
    let sendAsset: MultichainAsset
    let receiveAsset: MultichainAsset
    let slippage: MultichainSwapSlippage?
    let sendCardRateText: String?
    let receiveCardRateText: String?
    let validationState: MultichainSwapValidationState
    let quote: MultichainSwapQuoteSnapshot

    var shouldShowReceiveQuoteShimmer: Bool {
        quote.quoteState == .loading && receiveAmount.isEmpty
    }

    var isReceiveQuoteUnavailable: Bool {
        quote.quoteState == .failed && receiveAmount.isEmpty
    }
}
