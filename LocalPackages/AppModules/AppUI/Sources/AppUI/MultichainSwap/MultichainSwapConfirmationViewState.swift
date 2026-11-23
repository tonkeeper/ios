import Foundation

/// The swap settings sheet: what the swap screen's quote and its prepared plan say about the swap.
public struct MultichainSwapConfirmationViewState: Equatable {
    public enum QuoteProgress: Equatable {
        case loading
        /// The swap screen's refresh countdown, from where it stands.
        case countdown(startDate: Date, duration: TimeInterval)
        case none
    }

    public struct NetworkFee: Equatable {
        public let title: String
        public let value: String
        /// Names what pays the fee; empty while nothing has priced it.
        public let method: String
        public let subtitle: String
        /// Nothing can pay the fee, and the subtitle says what is missing.
        public let isShortage: Bool
        public let canPickMethod: Bool

        public init(
            title: String,
            value: String,
            method: String,
            subtitle: String,
            isShortage: Bool = false,
            canPickMethod: Bool
        ) {
            self.title = title
            self.value = value
            self.method = method
            self.subtitle = subtitle
            self.isShortage = isShortage
            self.canPickMethod = canPickMethod
        }
    }

    /// What the swap locks on top of its fee and refunds once it is done with it.
    public struct TemporaryReserve: Equatable {
        public let value: String
        public let hint: String

        public init(value: String, hint: String) {
            self.value = value
            self.hint = hint
        }
    }

    public enum Action: Equatable {
        case swap(isEnabled: Bool, isLoading: Bool)
        /// Nothing can pay the fee: Swap looks blocked, and a tap opens the ways to pay it.
        case feeUnpaid
        /// The battery is all that could pay and it is short, so the button goes to the top-up.
        case topUpBattery
        /// The swap screen's quote failed: the reason, then a way to ask again.
        case quoteFailed(String)
        /// A send whose outcome is unknown: nothing more is sent from here.
        case sendFailed(String)
    }

    public let rateLine: String
    public let quoteProgress: QuoteProgress
    public let minimumReceivedLine: String
    public let minimumReceivedFiatLine: String?
    public let slippageLine: String
    public let canSelectSlippage: Bool
    public let networkFee: NetworkFee
    public let temporaryReserve: TemporaryReserve?
    public let action: Action

    public init(
        rateLine: String,
        quoteProgress: QuoteProgress,
        minimumReceivedLine: String,
        minimumReceivedFiatLine: String?,
        slippageLine: String,
        canSelectSlippage: Bool,
        networkFee: NetworkFee,
        temporaryReserve: TemporaryReserve? = nil,
        action: Action
    ) {
        self.rateLine = rateLine
        self.quoteProgress = quoteProgress
        self.minimumReceivedLine = minimumReceivedLine
        self.minimumReceivedFiatLine = minimumReceivedFiatLine
        self.slippageLine = slippageLine
        self.canSelectSlippage = canSelectSlippage
        self.networkFee = networkFee
        self.temporaryReserve = temporaryReserve
        self.action = action
    }
}
