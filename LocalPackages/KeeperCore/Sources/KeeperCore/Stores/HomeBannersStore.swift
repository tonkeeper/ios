import Foundation

public final class HomeBannersStore: Store<HomeBannersStore.Event, HomeBannersCatalogue> {
    public enum Event {
        case didUpdateBanners
        case didDismissBanner
    }

    private let repository: HomeBannersRepository

    init(repository: HomeBannersRepository) {
        self.repository = repository
        super.init(state: .empty)
    }

    override public func createInitialState() -> HomeBannersCatalogue {
        .empty
    }

    public func visibleBanners(for wallet: Wallet) -> [HomeBanner] {
        let dismissedIds = Set(repository.getDismissedBannerIds(walletId: wallet.id))
        return state
            .banners(forWalletId: wallet.multichainWalletState?.walletId)
            .filter { !dismissedIds.contains($0.id) }
    }

    func setBanners(_ banners: [HomeBanner], forWalletId walletId: String?) async {
        await withCheckedContinuation { continuation in
            setBanners(banners, forWalletId: walletId) {
                continuation.resume()
            }
        }
    }

    public func dismissBanner(id: String, walletId: String) {
        repository.appendDismissedBannerId(id, walletId: walletId)
        sendEvent(.didDismissBanner)
    }

    public func resetDismissedBanners() {
        repository.resetDismissedBannerIds()
        sendEvent(.didUpdateBanners)
    }

    private func setBanners(
        _ banners: [HomeBanner],
        forWalletId walletId: String?,
        completion: (() -> Void)? = nil
    ) {
        guard getState().banners(forWalletId: walletId) != banners else {
            completion?()
            return
        }

        updateState { state in
            StateUpdate(newState: state.setting(banners, forWalletId: walletId))
        } completion: { [weak self] _ in
            self?.sendEvent(.didUpdateBanners)
            completion?()
        }
    }
}
