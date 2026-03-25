import CoreComponents
import Foundation

protocol BuySellMethodsRepository {}

final class BuySellMethodsRepositoryImplementation: BuySellMethodsRepository {
    let fileSystemVault: FileSystemVault<FiatMethods, String>

    init(fileSystemVault: FileSystemVault<FiatMethods, String>) {
        self.fileSystemVault = fileSystemVault
    }
}

private extension String {
    static let key = "FiatMethods"
}
