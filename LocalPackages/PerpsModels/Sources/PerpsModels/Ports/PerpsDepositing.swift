import Foundation
import OperationReviewModels

public enum PerpsDepositOutcome: Sendable, Equatable {
    /// The payment was sent, but its registration proof needs another unlock.
    case authorizationRequired(operationId: String)
    /// Paid and recorded. `PerpsFundingRecovery` owns it from here.
    case registered(operationId: String)

    public var operationId: String {
        switch self {
        case let .authorizationRequired(operationId), let .registered(operationId):
            operationId
        }
    }
}

/// Funding operations by id: sending, accepted withdrawals awaiting L1, arrivals and failures.
public struct PerpsFundingActivity: Sendable, Equatable {
    public let isBalanceRefreshing: Bool
    public let deposits: [PerpsDepositStatus]
    public let acknowledgedDepositIds: Set<String>
    public let inFlight: Set<String>
    public let pending: Set<String>
    public let completed: Set<String>
    /// Deposits the provider failed or refunded, and withdrawals Lighter rejected.
    public let failed: Set<String>
    /// The hashes each operation put on chain, by operation id: what finds it in the history.
    public let transactions: [String: Set<String>]
    /// Which of the operations above are withdrawals.
    public let withdrawals: Set<String>

    public init(
        isBalanceRefreshing: Bool = false,
        deposits: [PerpsDepositStatus] = [],
        inFlight: Set<String> = [],
        pending: Set<String> = [],
        completed: Set<String> = [],
        failed: Set<String> = [],
        transactions: [String: Set<String>] = [:],
        withdrawals: Set<String> = [],
        acknowledgedDepositIds: Set<String> = []
    ) {
        self.isBalanceRefreshing = isBalanceRefreshing
        self.deposits = deposits
        self.acknowledgedDepositIds = acknowledgedDepositIds
        self.inFlight = inFlight
        self.pending = pending
        self.completed = completed
        self.failed = failed
        self.transactions = transactions
        self.withdrawals = withdrawals
    }

    public var ended: Set<String> {
        completed.union(failed)
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
    /// The quote signed after the passcode credits less than the one reviewed, so nothing was sent.
    case quoteChanged
    /// The amount and the chain's own fee together exceed the balance.
    case insufficientBalance
    /// `required` is what the balance must hold, a decimal string in whole coins: the fee, plus
    /// the amount when it is paid in the same coin. `nil` when the fee is not known.
    case insufficientNetworkFee(symbol: String, required: String? = nil)
    /// Another deposit of this wallet is creating its Perps account; others wait until it closes.
    case accountCreationPending
    /// The deposit provider refuses transfers from this wallet's address on the source's chain
    /// (an AML block), whatever the amount.
    case addressBlocked
    case regionRestricted
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

public extension PerpsFundingBalance {
    var usdValue: Decimal? {
        guard let usdPrice, !usdPrice.isNaN, usdPrice >= 0,
              let amount = Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX")),
              !amount.isNaN, amount >= 0
        else { return nil }
        let value = amount * usdPrice
        return value.isNaN ? nil : value
    }
}

public extension Array where Element == PerpsDepositSourceOption {
    var sortedByHoldingValue: [PerpsDepositSourceOption] {
        sorted { ($0.balance?.usdValue ?? 0) > ($1.balance?.usdValue ?? 0) }
    }

    var largestHolding: PerpsDepositSourceOption? {
        filter { ($0.balance?.usdValue ?? 0) > 0 }
            .max { ($0.balance?.usdValue ?? 0) < ($1.balance?.usdValue ?? 0) }
    }

    var depositableCount: Int {
        filter { ($0.balance?.usdValue ?? 0) >= PerpsDepositSources.gatewayMinimumUsd }.count
    }
}

public struct PerpsDepositSources: Sendable, Equatable {
    public static let gatewayMinimumUsd: Decimal = 1

    public let options: [PerpsDepositSourceOption]
    public let isFresh: Bool

    public init(options: [PerpsDepositSourceOption], isFresh: Bool) {
        self.options = options
        self.isFresh = isFresh
    }
}

/// The fees a deposit's provider states, in dollars. The source chain's own fee is not among them.
public struct PerpsDepositProviderFees: Sendable, Equatable {
    /// The Ethereum gas of delivering the USDC to Lighter's gateway.
    public let destinationGasUsd: Decimal
    /// The provider's own fee, and any it names that the wallet does not know.
    public let providerUsd: Decimal

    public init(destinationGasUsd: Decimal, providerUsd: Decimal) {
        self.destinationGasUsd = destinationGasUsd
        self.providerUsd = providerUsd
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
    /// What pays the network fee, as the fee picker names it: shown after the fee total. `nil`
    /// where only the chain's own coin can pay.
    public let feeMethodTitle: String?
    /// Battery charges pay the network fee: the Fee row names them rather than their dollars,
    /// which only weigh the fee against the amount.
    public let paysFeeInCharges: Bool
    /// What the fee method holds on top of the fee and gives back once the deposit is processed,
    /// as it is spelled for display: Battery charges. `nil` when it holds nothing extra.
    public let networkFeeReserve: String?
    /// The chain's own coin when no method covers the fee, as a swap names it: confirming then
    /// asks for a method to top up.
    public let feeShortageSymbol: String?
    /// `nil` when unknown.
    public let providerFees: PerpsDepositProviderFees?
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
    /// Whether this quote creates the account; `nil` when unknown.
    public let accountUninitialized: Bool?
    /// This deposit creates the Perps account, which makes it cost and take more than later ones.
    public let createsAccount: Bool
    public let sentAmount: String?
    public let provider: String?

    public init(
        sourceAmount: String,
        sourceSymbol: String,
        creditedAmount: String,
        creditedSymbol: String,
        networkFee: String?,
        networkFeeSymbol: String,
        networkFeeUsd: Decimal? = nil,
        feeMethodTitle: String? = nil,
        paysFeeInCharges: Bool = false,
        networkFeeReserve: String? = nil,
        feeShortageSymbol: String? = nil,
        providerFees: PerpsDepositProviderFees? = nil,
        resumesPayment: Bool = false,
        expiresAt: Date? = nil,
        estimatedDurationSeconds: Int? = nil,
        delegatedNetworks: [PerpsFundingNetwork] = [],
        accountUninitialized: Bool? = nil,
        createsAccount: Bool = false,
        sentAmount: String? = nil,
        provider: String? = nil
    ) {
        self.sourceAmount = sourceAmount
        self.sourceSymbol = sourceSymbol
        self.creditedAmount = creditedAmount
        self.creditedSymbol = creditedSymbol
        self.networkFee = networkFee
        self.networkFeeSymbol = networkFeeSymbol
        self.networkFeeUsd = networkFeeUsd
        self.feeMethodTitle = feeMethodTitle
        self.paysFeeInCharges = paysFeeInCharges
        self.networkFeeReserve = networkFeeReserve
        self.feeShortageSymbol = feeShortageSymbol
        self.providerFees = providerFees
        self.resumesPayment = resumesPayment
        self.expiresAt = expiresAt
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.delegatedNetworks = delegatedNetworks
        self.accountUninitialized = accountUninitialized
        self.createsAccount = createsAccount
        self.sentAmount = sentAmount
        self.provider = provider
    }
}

public struct PerpsReviewedDeposit: Sendable {
    public let terms: PerpsDepositTerms
    /// What confirming signs first, as the checks read it: it tones the confirm control and is
    /// asked about before the passcode. `nil` when there is nothing to show.
    public let review: OperationReview?
    /// Bound to the quote `terms` were read from: paying never re-reads them elsewhere. `consent`
    /// is the confirm attempt's, so what it already accepted is not asked about again.
    public let pay: @Sendable (_ passcode: String, _ consent: OperationConsent) async throws -> PerpsDepositOutcome
    /// Asks how to pay the fee and hands back the same quote reviewed for the method picked, or
    /// `nil` once a method was topped up, which the quote is reviewed again for; a dismissed
    /// picker hands back nothing. Absent where only the chain's own coin can pay.
    public let pickFee: PerpsDepositFeePicking?

    public init(
        terms: PerpsDepositTerms,
        review: OperationReview? = nil,
        pickFee: PerpsDepositFeePicking? = nil,
        pay: @escaping @Sendable (_ passcode: String, _ consent: OperationConsent) async throws -> PerpsDepositOutcome
    ) {
        self.terms = terms
        self.review = review
        self.pickFee = pickFee
        self.pay = pay
    }
}

public typealias PerpsDepositFeePicking = @MainActor @Sendable (
    _ picked: @escaping @MainActor (PerpsReviewedDeposit?) -> Void
) -> Void

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
    /// `nil` while the source's floor is unknown: review still names it. Throws only what refuses
    /// every amount of the source, such as a blocked sender address.
    func loadMinimum() async throws -> PerpsDepositMinimum?
    func availableSources() async -> PerpsDepositSources
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

    func loadMinimum() async throws -> PerpsDepositMinimum? {
        nil
    }

    func availableSources() async -> PerpsDepositSources {
        PerpsDepositSources(options: [PerpsDepositSourceOption(source: source, balance: await loadBalance())], isFresh: true)
    }

    func selectSource(assetId _: String) {}

    func pendingReview() async throws -> PerpsReviewedDeposit? {
        nil
    }
}
