import CoreComponents
import Foundation
import TonSwift

public extension TransactionsManagement {
    protocol Repository {
        func getTransactionState(wallet: Wallet, txID: txID) -> TransactionState
        func getTransactionsStates(wallet: Wallet) -> TransactionsStates
        func setTransactionState(wallet: Wallet, txID: txID, state: TransactionState) throws
    }
}

extension TransactionsManagement {
    struct RepositoryImplementation: Repository {
        let fileSystemVault: FileSystemVault<TransactionsStates, FriendlyAddress>

        init(fileSystemVault: FileSystemVault<TransactionsStates, FriendlyAddress>) {
            self.fileSystemVault = fileSystemVault
        }

        func getTransactionState(wallet: Wallet, txID: txID) -> TransactionState {
            let states = getTransactionsStates(wallet: wallet)
            return states.states[txID] ?? .normal
        }

        func getTransactionsStates(wallet: Wallet) -> TransactionsStates {
            do {
                return try fileSystemVault.loadItem(key: wallet.friendlyAddress)
            } catch {
                return TransactionsStates(states: [:])
            }
        }

        func setTransactionState(wallet: Wallet, txID: txID, state: TransactionState) throws {
            let states = getTransactionsStates(wallet: wallet)
            var updatedStates = states.states
            updatedStates[txID] = state
            try fileSystemVault.saveItem(
                TransactionsManagement.TransactionsStates(states: updatedStates),
                key: wallet.friendlyAddress
            )
        }
    }
}
