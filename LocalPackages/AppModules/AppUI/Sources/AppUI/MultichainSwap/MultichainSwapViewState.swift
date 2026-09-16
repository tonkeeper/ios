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
        public let canContinue: Bool

        public init(
            sendCard: AmountCard,
            receiveCard: AmountCard,
            quote: Quote,
            canContinue: Bool
        ) {
            self.sendCard = sendCard
            self.receiveCard = receiveCard
            self.quote = quote
            self.canContinue = canContinue
        }
    }

    public struct AmountCard: Equatable {
        public let amount: String
        public let amountPrefix: String?
        public let amountState: MultichainSwapAmountState
        public let showsQuoteShimmer: Bool
        public let quoteUnavailableText: String?
        public let insufficientBalanceText: String?
        public let balanceText: String?
        public let rateText: String?
        public let maximumFractionDigits: Int
        public let decimalSeparator: String
        public let token: Token

        public init(
            amount: String,
            amountPrefix: String? = nil,
            amountState: MultichainSwapAmountState = .editable,
            showsQuoteShimmer: Bool = false,
            quoteUnavailableText: String? = nil,
            insufficientBalanceText: String? = nil,
            balanceText: String?,
            rateText: String? = nil,
            maximumFractionDigits: Int,
            decimalSeparator: String = ".",
            token: Token
        ) {
            self.amount = amount
            self.amountPrefix = amountPrefix
            self.amountState = amountState
            self.showsQuoteShimmer = showsQuoteShimmer
            self.quoteUnavailableText = quoteUnavailableText
            self.insufficientBalanceText = insufficientBalanceText
            self.balanceText = balanceText
            self.rateText = rateText
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
            case idle
            case loading
            case failed
            case ready
            case expired
        }

        public let mode: Mode
        public let rateText: String
        public let progressRestartToken: Int
        public let refreshDuration: TimeInterval

        public init(
            mode: Mode,
            rateText: String,
            progressRestartToken: Int = 0,
            refreshDuration: TimeInterval
        ) {
            self.mode = mode
            self.rateText = rateText
            self.progressRestartToken = progressRestartToken
            self.refreshDuration = refreshDuration
        }
    }

    public let content: Content
    public let promoTitle: String?
    public let focusRequestID: Int

    public init(
        content: Content,
        promoTitle: String? = nil,
        focusRequestID: Int = 0
    ) {
        self.content = content
        self.promoTitle = promoTitle
        self.focusRequestID = focusRequestID
    }

    public var isLoaded: Bool {
        if case .loaded = content {
            return true
        }
        return false
    }
}
