import Foundation
import TonAPI
import TonSwift

protocol TonBalanceService {
    func loadBalance(wallet: Wallet) async throws -> TonBalance
}

final class TonBalanceServiceImplementation: TonBalanceService {
    private let apiProvider: APIProvider

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    func loadBalance(wallet: Wallet) async throws -> TonBalance {
        let account = try await apiProvider.api(wallet.network).getAccountInfo(accountId: wallet.address.toRaw())
        return TonBalance(amount: account.balance)
    }
}
