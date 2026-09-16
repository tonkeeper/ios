import Foundation
import KeeperCoreComponents

protocol PopularAppsRepository {
    func savePopularApps(_ popularApps: PopularAppsResponseData, lang: String, walletId: String?) throws
    func getPopularApps(lang: String, walletId: String?) throws -> PopularAppsResponseData
}

final class PopularAppsRepositoryImplementation: PopularAppsRepository {
    let fileSystemVault: FileSystemVault<PopularAppsResponseData, String>

    init(fileSystemVault: FileSystemVault<PopularAppsResponseData, String>) {
        self.fileSystemVault = fileSystemVault
    }

    func savePopularApps(_ popularApps: PopularAppsResponseData, lang: String, walletId: String?) throws {
        let key = key(lang: lang, walletId: walletId)
        try fileSystemVault.saveItem(popularApps, key: key)
    }

    func getPopularApps(lang: String, walletId: String?) throws -> PopularAppsResponseData {
        let key = key(lang: lang, walletId: walletId)
        return try fileSystemVault.loadItem(key: key)
    }
}

private extension PopularAppsRepositoryImplementation {
    func key(lang: String, walletId: String?) -> String {
        if let walletId {
            return "\(String.key)_\(walletId)_\(lang)"
        } else {
            return "\(String.key)_\(lang)"
        }
    }
}

private extension String {
    static let key = "PopularApps"
}
