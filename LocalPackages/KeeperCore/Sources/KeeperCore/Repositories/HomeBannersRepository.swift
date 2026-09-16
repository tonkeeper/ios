import Foundation
import KeeperCoreComponents

struct HomeBannersRepository {
    let fileSystemVault: FileSystemVault<[String: [String]], String>

    func getDismissedBannerIds(walletId: String) -> [String] {
        getAllDismissedBannerIds()[walletId] ?? []
    }

    func appendDismissedBannerId(_ id: String, walletId: String) {
        var dismissedByWallet = getAllDismissedBannerIds()
        var ids = dismissedByWallet[walletId] ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        dismissedByWallet[walletId] = ids
        try? fileSystemVault.saveItem(dismissedByWallet, key: .dismissedHomeBannerIds)
    }

    func resetDismissedBannerIds() {
        try? fileSystemVault.saveItem([String: [String]](), key: .dismissedHomeBannerIds)
    }

    private func getAllDismissedBannerIds() -> [String: [String]] {
        (try? fileSystemVault.loadItem(key: .dismissedHomeBannerIds)) ?? [:]
    }
}

private extension String {
    static let dismissedHomeBannerIds = "dismissedHomeBannerIds"
}
