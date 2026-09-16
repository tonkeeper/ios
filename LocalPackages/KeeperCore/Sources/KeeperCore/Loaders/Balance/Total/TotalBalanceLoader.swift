import Foundation

protocol TotalBalanceLoader {
    func reloadBalances(
        wallets: [Wallet],
        activeWallet: Wallet?,
        currency: Currency
    ) async
}
