import Foundation
import TKUIKit

public struct MultichainSwapViewState: Equatable {
    public enum Content: Equatable {
        case shimmer
        case error
        case loaded(Loaded)
    }

    public struct Loaded: Equatable {
        public let sendCard: AmountCard
        public let receiveCard: AmountCard
        public let quote: Quote
        public let continueButton: ContinueButton

        public init(
            sendCard: AmountCard,
            receiveCard: AmountCard,
            quote: Quote,
            continueButton: ContinueButton
        ) {
            self.sendCard = sendCard
            self.receiveCard = receiveCard
            self.quote = quote
            self.continueButton = continueButton
        }
    }

    public enum ContinueButton: Equatable {
        case swap(isEnabled: Bool)
        /// There is nothing to swap yet, and the title says why.
        case blocked(String)
        /// Nothing can pay the fee: the button looks blocked, and a tap opens the ways to pay it.
        case feeUnpaid
        /// The fee falls to the battery and it is short, so the button goes to the top-up.
        case topUpBattery

        public var isEnabled: Bool {
            self == .swap(isEnabled: true) || self == .feeUnpaid || self == .topUpBattery
        }
    }

    public struct AmountCard: Equatable {
        public let amount: String
        public let amountPrefix: String?
        public let amountState: MultichainSwapAmountState
        public let showsQuoteShimmer: Bool
        public let quoteUnavailableText: String?
        public let exceedsBalance: Bool
        public let balanceText: String?
        public let rateText: String?
        /// Set on the receive card while the route moves the price too far.
        public let priceImpact: PriceImpact?
        public let maximumFractionDigits: Int
        public let decimalSeparator: String
        public let token: Token

        public init(
            amount: String,
            amountPrefix: String? = nil,
            amountState: MultichainSwapAmountState = .editable,
            showsQuoteShimmer: Bool = false,
            quoteUnavailableText: String? = nil,
            exceedsBalance: Bool = false,
            balanceText: String?,
            rateText: String? = nil,
            priceImpact: PriceImpact? = nil,
            maximumFractionDigits: Int,
            decimalSeparator: String = ".",
            token: Token
        ) {
            self.amount = amount
            self.amountPrefix = amountPrefix
            self.amountState = amountState
            self.showsQuoteShimmer = showsQuoteShimmer
            self.quoteUnavailableText = quoteUnavailableText
            self.exceedsBalance = exceedsBalance
            self.balanceText = balanceText
            self.rateText = rateText
            self.priceImpact = priceImpact
            self.maximumFractionDigits = maximumFractionDigits
            self.decimalSeparator = decimalSeparator
            self.token = token
        }
    }

    public struct Token: Equatable {
        public let avatarSource: AssetAvatarViewImageSource
        public let symbol: String
        public let network: String?

        public init(
            avatarSource: AssetAvatarViewImageSource,
            symbol: String,
            network: String?
        ) {
            self.avatarSource = avatarSource
            self.symbol = symbol
            self.network = network
        }
    }

    public struct Quote: Equatable {
        public enum Mode: Equatable {
            /// Nothing is entered yet, and the row stays empty.
            case hidden
            /// Nothing is entered yet, and the row offers the battery to a wallet that has none; a tap
            /// opens its top-up.
            case batteryPromo(String)
            case loading
            /// The quote is in, and its network fee is still being estimated.
            case estimatingFee
            /// Why there is no quote to act on.
            case failed(String)
            /// What pays the network fee; a tap opens the pricing details.
            case fee(Fee)
        }

        public struct Fee: Equatable {
            public enum Icon: Equatable {
                case battery
                case exclamationMark
            }

            public let text: String
            public let icon: Icon?
            /// Nothing can pay the fee.
            public let isShortage: Bool

            public init(text: String, icon: Icon? = nil, isShortage: Bool = false) {
                self.text = text
                self.icon = icon
                self.isShortage = isShortage
            }
        }

        public let mode: Mode

        public init(mode: Mode) {
            self.mode = mode
        }
    }

    public struct PriceImpact: Equatable {
        public enum Severity: Equatable {
            case warning
            case danger

            var color: TKColor {
                switch self {
                case .warning:
                    .accentOrange
                case .danger:
                    .accentRed
                }
            }
        }

        public let severity: Severity
        public let text: String

        public init(severity: Severity, text: String) {
            self.severity = severity
            self.text = text
        }
    }

    public let content: Content
    public let promoTitle: String?
    public let focusRequestID: Int
    /// Where a focus request lands: the field whose amount the user entered, unless that field cannot
    /// take typing.
    public let focusField: MultichainSwapAmountField
    /// The Swap button started a swap: it spins, and the screen can be neither edited nor closed until it
    /// hands over.
    public let isSwapping: Bool
    /// A swap failed to send: why takes the presets' and the button's place, and nothing on the screen
    /// starts a swap meanwhile.
    public let sendFailure: String?

    public init(
        content: Content,
        promoTitle: String? = nil,
        focusRequestID: Int = 0,
        focusField: MultichainSwapAmountField = .send,
        isSwapping: Bool = false,
        sendFailure: String? = nil
    ) {
        self.content = content
        self.promoTitle = promoTitle
        self.focusRequestID = focusRequestID
        self.focusField = focusField
        self.isSwapping = isSwapping
        self.sendFailure = sendFailure
    }

    public var isLoaded: Bool {
        if case .loaded = content {
            return true
        }
        return false
    }
}
