import Foundation

/// tk-perps reads the account's open orders with a read-only token minted at Lighter, and
/// without one the trading screen answers with no orders at all — which the planner reads as
/// an incomplete account and refuses every limit order on. Minting needs only the short-lived
/// Lighter authorization the trading key produces.
actor PerpsReadOnlyToken {
    static let reissueInterval: TimeInterval = 60

    private let mint: @Sendable () async -> Bool
    private let now: @Sendable () -> Date
    private var minting: Task<Bool, Never>?
    private var mintedAt: Date?

    init(
        mint: @escaping @Sendable () async -> Bool,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.mint = mint
        self.now = now
    }

    /// A caller arriving mid-mint takes that mint's answer: refused, it would read its orders
    /// as if the wallet had no token while the one being minted is about to land.
    @discardableResult
    func issue() async -> Bool {
        if let minting { return await minting.value }
        if let mintedAt, now().timeIntervalSince(mintedAt) < Self.reissueInterval { return false }
        mintedAt = now()
        let task = Task { await mint() }
        minting = task
        defer { minting = nil }
        return await task.value
    }
}
