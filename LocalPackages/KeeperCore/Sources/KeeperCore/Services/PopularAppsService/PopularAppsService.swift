import Foundation

public protocol PopularAppsService {
    func loadPopularApps(lang: String) async throws -> PopularAppsResponseData
    func getPopularApps(lang: String) throws -> PopularAppsResponseData
}

final class PopularAppsServiceImplementation: PopularAppsService {
    private let api: TonkeeperAPI
    private let popularAppsRepository: PopularAppsRepository
    private let walletsStore: WalletsStore

    init(
        api: TonkeeperAPI,
        popularAppsRepository: PopularAppsRepository,
        walletsStore: WalletsStore
    ) {
        self.api = api
        self.popularAppsRepository = popularAppsRepository
        self.walletsStore = walletsStore
    }

    func loadPopularApps(lang: String) async throws -> PopularAppsResponseData {
        let walletId = multichainWalletId
        do {
            let popularApps = try await api.loadPopularApps(lang: lang, walletId: walletId)
            try? popularAppsRepository.savePopularApps(
                popularApps,
                lang: lang,
                walletId: walletId
            )
            return popularApps
        } catch {
            try? popularAppsRepository.savePopularApps(
                .empty,
                lang: lang,
                walletId: walletId
            )
            throw error
        }
    }

    func getPopularApps(lang: String) throws -> PopularAppsResponseData {
        try popularAppsRepository.getPopularApps(
            lang: lang,
            walletId: multichainWalletId
        )
    }

    private var multichainWalletId: String? {
        (try? walletsStore.activeWallet)?.multichainWalletState?.walletId
    }
}
