import Foundation
import KeeperCore
import TronSwift

final class SettingsUSDTTronBalanceLoader {
    var didUpdateBalance: (() -> Void)?
    private let address: TronSwift.Address?

    private let tronBalanceService: TronBalanceService
    private var cachedHasPositiveBalance: Bool?
    private var isLoadingBalance = false

    init(tronBalanceService: TronBalanceService, address: TronSwift.Address?) {
        self.tronBalanceService = tronBalanceService
        self.address = address
    }

    func hasPositiveBalance() -> Bool {
        guard address != nil else { return false }

        if cachedHasPositiveBalance == nil {
            loadBalanceIfNeeded()
        }
        return cachedHasPositiveBalance == true
    }

    private func loadBalanceIfNeeded() {
        guard let address else { return }
        guard cachedHasPositiveBalance == nil else { return }
        guard !isLoadingBalance else { return }

        isLoadingBalance = true
        Task { [weak self] in
            guard let self else { return }

            let hasPositiveBalance = (try? await tronBalanceService.loadBalance(address: address, includingTransferFees: true))
                .map { !$0.amount.isZero }
            await applyLoadedBalance(hasPositiveBalance: hasPositiveBalance)
        }
    }

    @MainActor
    private func applyLoadedBalance(hasPositiveBalance: Bool?) {
        isLoadingBalance = false
        guard let hasPositiveBalance else { return }
        cachedHasPositiveBalance = hasPositiveBalance
        didUpdateBalance?()
    }
}
