import Foundation
import TKLogging

public final class HomeBannersLoader {
    private let loader: WalletScopedLoader<[HomeBanner]?>

    init(
        tonkeeperAPI: TonkeeperAPI,
        configuration: Configuration,
        homeBannersStore: HomeBannersStore,
        walletsStore: WalletsStore
    ) {
        loader = WalletScopedLoader(
            walletsStore: walletsStore,
            fetch: { walletId in
                do {
                    let banners = try await tonkeeperAPI.loadBanners(walletId: walletId)
                    _ = await configuration.loadConfigurations()
                    return banners.filter { !configuration.isPromoHidden(id: $0.id) }
                } catch {
                    Log.w("Failed to load home banners for wallet \(walletId ?? "none"): \(error)")
                    return nil
                }
            },
            apply: { walletId, banners in
                guard let banners else { return }
                await homeBannersStore.setBanners(banners, forWalletId: walletId)
            }
        )
    }

    public func loadBanners(scope: WalletScope, force: Bool) async {
        await loader.reload(scope: scope, force: force)
    }
}
