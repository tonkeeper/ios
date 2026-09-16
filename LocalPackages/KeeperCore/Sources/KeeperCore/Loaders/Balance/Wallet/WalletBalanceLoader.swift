import Foundation

public protocol WalletBalanceLoader {
    @discardableResult
    func reloadBalance(
        currency: Currency,
        includingTransferFees: Bool
    ) async -> BalanceRefreshResult
}

public extension WalletBalanceLoader {
    @discardableResult
    func reloadBalance(
        currency: Currency
    ) async -> BalanceRefreshResult {
        await reloadBalance(
            currency: currency,
            includingTransferFees: true
        )
    }
}
