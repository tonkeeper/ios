import Foundation

public struct PerpsDepositStatus: Sendable, Equatable, Identifiable {
    public enum State: Sendable, Equatable {
        case pending, completed, failed, refunded, unconfirmed
    }

    public enum Step: Int, Sendable, Equatable, Codable {
        case sending, converting, adding
    }

    public let id: String
    public let createdAt: Date
    public let sourceAmount: String
    public let sourceSymbol: String
    public let sourceNetwork: String
    public let expectedAmount: String?
    public let creditedAmount: String?
    public let estimatedDurationSeconds: Int?
    public let state: State
    public let step: Step?
    public let skipsConversion: Bool

    public init(
        id: String,
        createdAt: Date,
        sourceAmount: String,
        sourceSymbol: String,
        sourceNetwork: String,
        expectedAmount: String?,
        creditedAmount: String? = nil,
        estimatedDurationSeconds: Int? = nil,
        state: State = .pending,
        step: Step? = nil,
        skipsConversion: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceAmount = sourceAmount
        self.sourceSymbol = sourceSymbol
        self.sourceNetwork = sourceNetwork
        self.expectedAmount = expectedAmount
        self.creditedAmount = creditedAmount
        self.estimatedDurationSeconds = estimatedDurationSeconds.flatMap { $0 > 0 ? $0 : nil }
        self.state = state
        self.step = step
        self.skipsConversion = skipsConversion
    }

    public var isUSDC: Bool {
        sourceSymbol.uppercased() == "USDC"
    }

    public func isDelayed(at date: Date) -> Bool {
        guard state == .pending, let estimatedDurationSeconds else { return false }
        return date.timeIntervalSince(createdAt) > Double(estimatedDurationSeconds)
    }
}
