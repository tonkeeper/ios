import Foundation
import os

public extension TransactionsManagement {
    final class Store {
        public enum Event {
            case updateStates(states: TransactionsStates)
            case updateState(txID: String, state: TransactionState)
        }

        public protocol Observer: AnyObject {
            func didGetTransactionsManagementStore(_ store: TransactionsManagement.Store, event: Event)
        }

        public var state: TransactionsStates {
            get {
                queue.sync {
                    loadStateIfNeeded()
                    return _state
                }
            }
            set {
                queue.async { [weak self] in
                    self?._state = newValue
                }
            }
        }

        private var _state = TransactionsStates(states: [:])
        private var observers = [ObserverWrapper]()
        private var didLoadState = false

        private let wallet: Wallet
        private let repository: Repository
        private let scamApi: ScamAPI
        private let queue = DispatchQueue(label: "com.walletconnect.transactions-management-store")

        init(
            wallet: Wallet,
            repository: Repository,
            scamApi: ScamAPI
        ) {
            self.wallet = wallet
            self.repository = repository
            self.scamApi = scamApi
        }

        public func addObserver(_ observer: Observer) {
            queue.async { [weak self] in
                guard let self else { return }
                observers = observers.filter { $0.observer != nil && $0.observer !== observer }
                    + CollectionOfOne(ObserverWrapper(observer: observer))
            }
        }

        public func markAsSpam(_ txID: txID) async {
            Task { [weak self] in
                guard let self else { return }
                try await scamApi.reportScamTransaction(txID, recipient: wallet.address)
            }
            await updateTxState(txID, .spam)
        }

        public func markAsNormal(_ txID: txID) async {
            await updateTxState(txID, .normal)
        }

        private func updateTxState(
            _ txID: txID,
            _ transactionState: TransactionState
        ) async {
            await withCheckedContinuation { continuation in
                updateTxState(txID, transactionState) {
                    continuation.resume()
                }
            }
        }

        private func updateTxState(
            _ txID: txID,
            _ transactionState: TransactionState,
            completion: @escaping () -> Void
        ) {
            queue.async { [weak self] in
                guard let self else { return }
                let state = _state
                var updated = state.states
                updated[txID] = transactionState
                try? repository.setTransactionState(wallet: wallet, txID: txID, state: transactionState)
                _state = TransactionsStates(states: updated)
                for item in observers {
                    item.observer?.didGetTransactionsManagementStore(
                        self,
                        event: .updateState(
                            txID: txID,
                            state: transactionState
                        )
                    )
                }
                for item in observers {
                    item.observer?.didGetTransactionsManagementStore(
                        self,
                        event: .updateStates(states: self._state)
                    )
                }
                completion()
            }
        }

        private struct ObserverWrapper {
            weak var observer: Observer?
        }

        private func loadStateIfNeeded() {
            guard !didLoadState else { return }
            _state = loadState()
            didLoadState = true
        }

        private func loadState() -> TransactionsStates {
            return repository.getTransactionsStates(wallet: wallet)
        }
    }
}
