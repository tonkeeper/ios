import Foundation
import KeeperCoreComponents

protocol BuySellMethodsRepository {}

final class BuySellMethodsRepositoryImplementation: BuySellMethodsRepository {
    let fileSystemVault: FileSystemVault<FiatMethods, String>

    init(fileSystemVault: FileSystemVault<FiatMethods, String>) {
        self.fileSystemVault = fileSystemVault
    }
}
