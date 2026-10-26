import Foundation

public enum PerpsWithdrawMessage: Sendable, Equatable {
    case belowMinimum(usdc: String)
    case quoteExpired
    case canceled
    case failed
}

/// The checked terms of one withdrawal, as the confirmation spells them.
public struct PerpsWithdrawTerms: Sendable, Equatable {
    /// The amount entered: a requote reviews it again. `nil` where nothing can be requoted.
    public let requestedAmount: String?
    /// USDC taken from the Perps balance, decimal string.
    public let withdrawAmount: String
    public let receiveAmount: String
    /// `receiveAmount` is a floor: a relay pays out what its fill buys.
    public let receivesAtLeast: Bool
    public let receiveSymbol: String
    public let networkFee: String?
    public let networkFeeSymbol: String
    public let networkFeeUsd: Decimal?
    public let expiresAt: Date?
    public let withdrawalDelaySeconds: Int?

    public init(
        requestedAmount: String? = nil,
        withdrawAmount: String,
        receiveAmount: String,
        receivesAtLeast: Bool = false,
        receiveSymbol: String,
        networkFee: String?,
        networkFeeSymbol: String,
        networkFeeUsd: Decimal? = nil,
        expiresAt: Date? = nil,
        withdrawalDelaySeconds: Int? = nil
    ) {
        self.requestedAmount = requestedAmount
        self.withdrawAmount = withdrawAmount
        self.receiveAmount = receiveAmount
        self.receivesAtLeast = receivesAtLeast
        self.receiveSymbol = receiveSymbol
        self.networkFee = networkFee
        self.networkFeeSymbol = networkFeeSymbol
        self.networkFeeUsd = networkFeeUsd
        self.expiresAt = expiresAt
        self.withdrawalDelaySeconds = withdrawalDelaySeconds
    }
}

public struct PerpsReviewedWithdraw: Sendable {
    public let terms: PerpsWithdrawTerms
    public let pay: @Sendable (_ passcode: String) async throws -> String

    public init(terms: PerpsWithdrawTerms, pay: @escaping @Sendable (_ passcode: String) async throws -> String) {
        self.terms = terms
        self.pay = pay
    }
}

/// One wallet's withdrawal from its Perps balance to its own address.
@MainActor
public protocol PerpsWithdrawing {
    /// What arrives in the wallet.
    var destination: PerpsDepositSource { get }
    func availableDestinations() async -> [PerpsDepositSourceOption]
    func selectDestination(assetId: String)
    /// USDC the Perps balance can give up now; `nil` while unknown.
    func loadBalance() async -> PerpsFundingBalance?
    func review(amount: String) async throws -> PerpsReviewedWithdraw
    func message(for error: Error) -> PerpsWithdrawMessage
}
