import Foundation

public final class TransactionsManagementAssembly {
    private let coreAssembly: CoreAssembly
    private let scamAPIAssembly: ScamAPIAssembly

    init(
        coreAssembly: CoreAssembly,
        scamAPIAssembly: ScamAPIAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.scamAPIAssembly = scamAPIAssembly
    }

    private var _transactionsManagementStores = [Wallet: Weak<TransactionsManagement.Store>]()
    public func transactionsManagementStore(wallet: Wallet) -> TransactionsManagement.Store {
        if let weakWrapper = _transactionsManagementStores[wallet],
           let store = weakWrapper.value
        {
            return store
        }
        let store = TransactionsManagement.Store(
            wallet: wallet,
            repository: transactionsManagementRepository(),
            scamApi: scamAPIAssembly.api
        )
        _transactionsManagementStores[wallet] = Weak(value: store)
        return store
    }

    private func transactionsManagementRepository() -> any TransactionsManagement.Repository {
        TransactionsManagement.RepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }
}
