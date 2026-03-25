import Foundation
import TonSwift

public final class BalanceStore: Store<BalanceStore.Event, BalanceStore.State> {
    public typealias State = [Wallet: WalletBalanceState]

    public enum Event {
        case didUpdateBalanceState(wallet: Wallet)
    }

    private let walletsStore: WalletsStore
    private let repository: WalletBalanceRepositoryV2

    init(
        walletsStore: WalletsStore,
        repository: WalletBalanceRepositoryV2
    ) {
        self.walletsStore = walletsStore
        self.repository = repository
        super.init(state: [:])
        setObservations()
    }

    override public func createInitialState() -> State {
        let wallets = walletsStore.wallets
        var state = State()
        for wallet in wallets {
            do {
                let balance = try repository.getBalance(address: wallet.friendlyAddress)
                state[wallet] = .previous(balance)
            } catch {
                state[wallet] = nil
            }
        }
        return state
    }

    public func setBalanceState(
        _ balanceState: WalletBalanceState,
        wallet: Wallet
    ) async {
        return await withCheckedContinuation { continuation in
            setBalanceState(balanceState, wallet: wallet) {
                continuation.resume()
            }
        }
    }

    public func setBalanceState(
        _ balanceState: WalletBalanceState,
        wallet: Wallet,
        completion: (() -> Void)?
    ) {
        updateState { state in
            var updatedState = state
            updatedState[wallet] = balanceState
            return StateUpdate(newState: updatedState)
        } completion: { _ in
            self.sendEvent(.didUpdateBalanceState(wallet: wallet))
            completion?()
        }
    }

    private func setObservations() {
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case let .didAddWallets(wallets):
                observer.updateState(wallets: wallets) { [weak observer] in
                    wallets.forEach { observer?.sendEvent(.didUpdateBalanceState(wallet: $0)) }
                }
            default: break
            }
        }
    }

    private func updateState(wallets: [Wallet], completion: @escaping () -> Void) {
        updateState { [weak self] state in
            guard let self else { return nil }
            var updatedState = state
            for wallet in wallets {
                guard state[wallet] == nil else { continue }
                guard let balance = try? self.repository.getBalance(address: wallet.friendlyAddress) else { continue }
                updatedState[wallet] = .previous(balance)
            }
            return StateUpdate(newState: updatedState)
        } completion: { _ in
            completion()
        }
    }
}
