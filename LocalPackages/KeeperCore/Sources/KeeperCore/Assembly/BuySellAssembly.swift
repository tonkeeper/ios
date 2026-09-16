import Foundation

public final class BuySellAssembly {
    private let tonkeeperApiAssembly: TonkeeperAPIAssembly
    private let coreAssembly: CoreAssembly

    init(
        tonkeeperApiAssembly: TonkeeperAPIAssembly,
        coreAssembly: CoreAssembly
    ) {
        self.tonkeeperApiAssembly = tonkeeperApiAssembly
        self.coreAssembly = coreAssembly
    }

    public func buySellMethodsService() -> BuySellMethodsService {
        BuySellMethodsServiceImplementation(
            api: tonkeeperApiAssembly.api,
            buySellMethodsRepository: buySellMethodsRepository()
        )
    }

    func buySellMethodsRepository() -> BuySellMethodsRepository {
        BuySellMethodsRepositoryImplementation(fileSystemVault: coreAssembly.fileSystemVault())
    }
}
