import Foundation

public enum PerpsDepositOutcome: Sendable, Equatable {
    /// The payment was sent, but its registration proof needs another unlock.
    case authorizationRequired(operationId: String)
    /// Paid and recorded. `PerpsFundingRecovery` owns it from here.
    case registered(operationId: String)
}

/// Funding operations by id: sending, accepted withdrawals awaiting L1, and arrivals.
public struct PerpsFundingActivity: Sendable, Equatable {
    public let inFlight: Set<String>
    public let pending: Set<String>
    public let completed: Set<String>
    /// The hashes each operation put on chain, by operation id: what finds it in the history.
    public let transactions: [String: Set<String>]

    public init(
        inFlight: Set<String> = [],
        pending: Set<String> = [],
        completed: Set<String> = [],
        transactions: [String: Set<String>] = [:]
    ) {
        self.inFlight = inFlight
        self.pending = pending
        self.completed = completed
        self.transactions = transactions
    }
}

/// What a screen may say about a failed deposit. The error cases themselves stay internal:
/// they name journal stages, calldata shapes and quote fields, and a screen branching on
/// those would have to change every time one of them does.
public enum PerpsDepositMessage: Sendable, Equatable {
    /// What is left once the route's fees are paid is under the gateway minimum, which Lighter
    /// never credits. `usd` is the smallest amount that clears it, a decimal string in dollars.
    case belowMinimum(usd: String)
    case quoteExpired
    /// The amount and the chain's own fee together exceed the balance.
    case insufficientBalance
    /// `required` is what the balance must hold, a decimal string in whole coins: the fee, plus
    /// the amount when it is paid in the same coin. `nil` when the fee is not known.
    case insufficientNetworkFee(symbol: String, required: String? = nil)
    /// Another deposit of this wallet is creating its Perps account; others wait until it closes.
    case accountCreationPending
    case canceled
    case failed
}

/// Source chains shown on the funding screens.
public enum PerpsFundingNetwork: Sendable, Equatable {
    case ton
    case ethereum
    case base
    case arbitrum
    case bsc
    case tron
    case bitcoin
    case sol
    case polygon
    case avax
    case robinhood
}

public struct PerpsDepositSource: Sendable, Equatable {
    public let assetId: String
    public let symbol: String
    public let decimals: Int
    public let network: PerpsFundingNetwork

    public init(assetId: String, symbol: String, decimals: Int, network: PerpsFundingNetwork) {
        self.assetId = assetId
        self.symbol = symbol
        self.decimals = decimals
        self.network = network
    }
}

public struct PerpsDepositSourceOption: Sendable, Equatable {
    public let source: PerpsDepositSource
    public let balance: PerpsFundingBalance?

    public init(source: PerpsDepositSource, balance: PerpsFundingBalance?) {
        self.source = source
        self.balance = balance
    }
}

/// What the wallet holds of a funding asset, as its own balance screens show it.
public struct PerpsFundingBalance: Sendable, Equatable {
    /// Decimal string in whole tokens.
    public let amount: String
    /// `nil` while the asset has no price: the screens then show no fiat value.
    public let usdPrice: Decimal?
    public let iconURL: URL?

    public init(amount: String, usdPrice: Decimal?, iconURL: URL?) {
        self.amount = amount
        self.usdPrice = usdPrice
        self.iconURL = iconURL
    }
}

/// The checked terms of one quote, as the confirmation spells them.
public struct PerpsDepositTerms: Sendable, Equatable {
    public let sourceAmount: String
    public let sourceSymbol: String
    public let creditedAmount: String
    public let creditedSymbol: String
    public let networkFee: String?
    public let networkFeeSymbol: String
    public let networkFeeUsd: Decimal?
    /// The terms of a payment signed earlier and never registered: confirming finishes it
    /// instead of paying the amount just entered.
    public let resumesPayment: Bool
    /// When the quote stops being payable; `nil` for a payment being finished.
    public let expiresAt: Date?
    /// The provider's estimate from sending to the credit; `nil` when it gives none.
    public let estimatedDurationSeconds: Int?
    /// Where paying delegates the wallet's address to a smart-account contract, which it keeps
    /// after the deposit, so the confirmation says so first.
    public let delegatedNetworks: [PerpsFundingNetwork]

    public init(
        sourceAmount: String,
        sourceSymbol: String,
        creditedAmount: String,
        creditedSymbol: String,
        networkFee: String?,
        networkFeeSymbol: String,
        networkFeeUsd: Decimal? = nil,
        resumesPayment: Bool = false,
        expiresAt: Date? = nil,
        estimatedDurationSeconds: Int? = nil,
        delegatedNetworks: [PerpsFundingNetwork] = []
    ) {
        self.sourceAmount = sourceAmount
        self.sourceSymbol = sourceSymbol
        self.creditedAmount = creditedAmount
        self.creditedSymbol = creditedSymbol
        self.networkFee = networkFee
        self.networkFeeSymbol = networkFeeSymbol
        self.networkFeeUsd = networkFeeUsd
        self.resumesPayment = resumesPayment
        self.expiresAt = expiresAt
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.delegatedNetworks = delegatedNetworks
    }
}

public struct PerpsReviewedDeposit: Sendable {
    public let terms: PerpsDepositTerms
    /// Bound to the quote `terms` were read from: paying never re-reads them elsewhere.
    public let pay: @Sendable (_ passcode: String) async throws -> PerpsDepositOutcome

    public init(
        terms: PerpsDepositTerms,
        pay: @escaping @Sendable (_ passcode: String) async throws -> PerpsDepositOutcome
    ) {
        self.terms = terms
        self.pay = pay
    }
}

/// The least a deposit of a source may be.
public struct PerpsDepositMinimum: Sendable, Equatable {
    public let usd: String
    /// In whole tokens of the source, rounded up.
    public let amount: Decimal

    public init(usd: String, amount: Decimal) {
        self.usd = usd
        self.amount = amount
    }
}

/// One wallet's deposit, already bound to the addresses it pays from and credits.
@MainActor
public protocol PerpsDepositing {
    var source: PerpsDepositSource { get }
    var walletName: String { get }
    var holdsTradingKey: Bool { get }
    func keepTradingKey(passcode: String) async -> Bool
    /// `nil` when the wallet's balance of the source cannot be read.
    func loadBalance() async -> PerpsFundingBalance?
    /// The most that can be sent, in whole tokens: a chain's own coin keeps back its fee.
    func loadLimit() async -> String?
    /// `nil` while the source's floor is unknown: review still names it.
    func loadMinimum() async -> PerpsDepositMinimum?
    func availableSources() async -> [PerpsDepositSourceOption]
    func selectSource(assetId: String)
    /// A payment already sent from this wallet that still needs registration.
    func pendingReview() async throws -> PerpsReviewedDeposit?
    func review(amount: String) async throws -> PerpsReviewedDeposit
    func message(for error: Error) -> PerpsDepositMessage
}

public extension PerpsDepositing {
    func loadLimit() async -> String? {
        await loadBalance()?.amount
    }

    func loadMinimum() async -> PerpsDepositMinimum? {
        nil
    }

    func availableSources() async -> [PerpsDepositSourceOption] {
        [PerpsDepositSourceOption(source: source, balance: await loadBalance())]
    }

    func selectSource(assetId _: String) {}

    func pendingReview() async throws -> PerpsReviewedDeposit? {
        nil
    }
}
