import BigInt
import Foundation
import KeeperCore
import TKUIKit

enum MultichainSwapQuoteState: Equatable {
    case idle
    case loading
    case ready
    case failed(MultichainSwapQuoteFailure)
}

enum MultichainSwapQuoteFailure: Equatable {
    case unavailable
    case pairUnavailable
    case walletScreened
    case offline
}

enum MultichainSwapValidationState: Equatable {
    case emptyAmount
    case invalidAmount
    /// The amount is under the least the asset can be swapped for, carried in base units.
    case belowMinimum(BigUInt)
    case insufficientBalance
    case missingAddress
    case routeUnavailable
    case valid

    var canEstimateFee: Bool {
        switch self {
        case .valid, .belowMinimum:
            return true
        case .emptyAmount, .invalidAmount, .insufficientBalance, .missingAddress, .routeUnavailable:
            return false
        }
    }

    var isBelowMinimum: Bool {
        if case .belowMinimum = self {
            return true
        }
        return false
    }
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

/// What runs over the swap screen once it hands its quote on.
enum MultichainSwapConfirmationPhase: Equatable {
    case pricingDetails
    /// Started by the Swap button: no sheet, the swap goes straight to the passcode.
    case swapping
}

/// A send that failed stands in for the presets and the Swap button, and the screen starts no swap meanwhile.
enum MultichainSwapSendFailure: Equatable {
    /// Carries why the send failed. Shown for a while, or until the input changes.
    case retryable(String)
    /// The relayer may still hold the signed message, so the same swap is not offered again: a second
    /// message could swap twice. Shown until the pair or the amount changes.
    case outcomeUnknown
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
    private(set) var receiveAmount: String
    var receiveAmountInputMode: MultichainSwapAmountInputMode
    /// The card whose amount the user typed and the quote is asked for; the other card shows what
    /// the quote derives from it.
    private(set) var enteredField: MultichainSwapAmountField
    private(set) var sendAsset: MultichainAsset
    /// Set only by the Max control and cleared by every other change to the amount or the asset
    /// being sold, so a rounded fiat round trip or a provider-normalized quote cannot lose it.
    private(set) var isMaxSend: Bool
    /// Send amount in the mode the send card is currently *not* in, dropped by every change to
    /// the amount or the asset being sold.
    private(set) var sendAmountToggle = AmountToggle<String>()
    var receiveAsset: MultichainAsset
    var slippage: MultichainSwapSlippage?
    /// Picks from the pricing details, so a swap started from this screen honours them. The options
    /// depend on the chain of the asset being sold, so changing that asset drops them.
    var slippageBps: Int?
    var feeMethod: MultichainSwapFeeMethod?
    /// USD → display-currency rate derived at the initial assets load.
    let usdFiatRate: Decimal?

    init(initialAssets: MultichainSwapInitialAssets) {
        self.sendAmount = ""
        self.sendAmountInputMode = .crypto
        self.receiveAmount = ""
        self.receiveAmountInputMode = .crypto
        self.enteredField = .send
        self.sendAsset = initialAssets.sendAsset
        self.isMaxSend = false
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
            return sendAmountToggle.counterpart
        }
    }

    func settingSendAmount(_ amount: String, isMax: Bool = false) -> MultichainSwapInputs {
        var inputs = self
        inputs.sendAmount = amount
        inputs.isMaxSend = isMax
        inputs.sendAmountToggle.reset()
        inputs.enteredField = .send
        return inputs
    }

    func settingReceiveAmount(_ amount: String) -> MultichainSwapInputs {
        var inputs = self
        inputs.receiveAmount = amount
        inputs.isMaxSend = false
        inputs.sendAmountToggle.reset()
        inputs.enteredField = .receive
        return inputs
    }

    var enteredAmountText: String {
        enteredField == .send ? sendAmount : receiveAmount
    }

    /// The text of the card the user did not type into: what the quote derives from the entered amount.
    var quotedAmountText: String {
        enteredField == .send ? receiveAmount : sendAmount
    }

    func settingQuotedAmount(_ amount: String) -> MultichainSwapInputs {
        var inputs = self
        switch enteredField {
        case .send:
            inputs.receiveAmount = amount
        case .receive:
            inputs.sendAmount = amount
            inputs.sendAmountToggle.reset()
        }
        return inputs
    }

    func settingSendAsset(_ asset: MultichainAsset) -> MultichainSwapInputs {
        var inputs = self
        inputs.sendAsset = asset
        inputs.isMaxSend = false
        inputs.sendAmountToggle.reset()
        inputs.slippageBps = nil
        inputs.feeMethod = nil
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
        inputs.sendAmount = inputs.sendAmountToggle.toggle(sendAmount, converted: convertedAmount)
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
    /// What pays the fee of the route on screen, or `nil` while its plan is on its way.
    let feeSummary: MultichainSwapFeeSummary?
    let enteredField: MultichainSwapAmountField
    let isReceiveAmountEditable: Bool
    /// The empty screen offers the battery to a wallet that has none, once.
    let showsBatteryPromo: Bool

    /// The card the user did not type into, where the quote shows.
    var quotedField: MultichainSwapAmountField {
        enteredField == .send ? .receive : .send
    }

    func showsQuoteShimmer(in field: MultichainSwapAmountField) -> Bool {
        field == quotedField && quote.quoteState == .loading && amount(in: field).isEmpty
    }

    func isQuoteUnavailable(in field: MultichainSwapAmountField) -> Bool {
        guard field == quotedField, case let .failed(failure) = quote.quoteState, failure != .offline else {
            return false
        }
        return amount(in: field).isEmpty
    }

    private func amount(in field: MultichainSwapAmountField) -> String {
        field == .send ? sendAmount : receiveAmount
    }
}
