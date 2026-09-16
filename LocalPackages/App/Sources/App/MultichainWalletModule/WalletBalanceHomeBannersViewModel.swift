import CoreGraphics
import Foundation
import KeeperCore
import TKCore
import TKUIKit

enum HomeBannersViewState {
    case idle
    case loading(data: [BannerItem], task: Task<Void, Never>)
    case loaded([BannerItem])

    var items: [BannerItem] {
        switch self {
        case .idle:
            []
        case let .loading(data, _):
            data
        case let .loaded(items):
            items
        }
    }

    /// Only a wait with nothing to show yet: a reload over a deck keeps rendering the deck.
    var showsShimmer: Bool {
        guard case let .loading(data, _) = self else { return false }
        return data.isEmpty
    }
}

/// Everything a deck is bound to: the wallet that dismisses banners and the seed they are answered
/// for. A rename leaves both alone, so it must not replace the model.
struct HomeBannersIdentity: Hashable {
    let walletId: String
    let scopeWalletId: String?

    init(wallet: Wallet) {
        walletId = wallet.id
        scopeWalletId = wallet.multichainWalletState?.walletId
    }
}

@MainActor
final class WalletBalanceHomeBannersViewModel: ObservableObject {
    @Published private(set) var state: HomeBannersViewState = .idle
    @Published private(set) var sectionHeight = WalletBalanceHomeBannersLayout.height(remainingCount: 0)
    @Published private(set) var isSectionVisible = false

    var onOpenDeeplink: ((Deeplink) -> Void)?
    var onOpenLink: ((URL) -> Void)?
    var onSectionVisibilityChanged: ((_ isVisible: Bool) -> Void)?
    var onSectionHeightChanged: ((_ height: CGFloat) -> Void)?

    let wallet: Wallet

    var identity: HomeBannersIdentity {
        HomeBannersIdentity(wallet: wallet)
    }

    private let homeBannersStore: HomeBannersStore
    private let homeBannersLoader: HomeBannersLoader
    private let deeplinkParser: DeeplinkParser
    private let analyticsProvider: AnalyticsProvider

    /// Banner ids already reported during the current on-screen appearance.
    /// Both sets are cleared in `handleBannersDisappeared`, so each appearance
    /// reports at most one view and one click per banner (keeping views and
    /// clicks symmetric for CTR).
    private var shownBannerIDs = Set<String>()
    private var clickedBannerIDs = Set<String>()

    init(
        wallet: Wallet,
        homeBannersStore: HomeBannersStore,
        homeBannersLoader: HomeBannersLoader,
        deeplinkParser: DeeplinkParser,
        analyticsProvider: AnalyticsProvider
    ) {
        self.wallet = wallet
        self.homeBannersStore = homeBannersStore
        self.homeBannersLoader = homeBannersLoader
        self.deeplinkParser = deeplinkParser
        self.analyticsProvider = analyticsProvider

        // The deck changes from outside this screen too — a load answering for the same seed, or
        // the dismissals being reset — so the store is what it follows, not only its own reload.
        homeBannersStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateBanners:
                Task { @MainActor in
                    observer.refreshBannerItems()
                }
            case .didDismissBanner:
                break
            }
        }
    }

    func loadIfNeeded() {
        guard case .idle = state else { return }
        reload(force: false)
    }

    func reload(force: Bool) {
        if case let .loading(_, task) = state {
            guard force else { return }
            task.cancel()
        }
        let loader = homeBannersLoader
        let scope = WalletScope.walletId(identity.scopeWalletId)
        let task = Task { [weak self] in
            await loader.loadBanners(scope: scope, force: force)
            guard !Task.isCancelled else { return }
            self?.finishLoading()
        }
        // Seeded from the store so a wallet already answered for keeps its deck while it refreshes.
        setState(.loading(data: visibleBannerItems(), task: task))
    }

    /// Called as the pop animation starts, not after it: the deck has already taken the card out
    /// of its own stack, and rebuilding the items here would remount it and drop the animation
    /// halfway. What the deck cannot do is resize or hide the section it sits in.
    func dismissBanner(_ item: BannerItem, remainingCount: Int) {
        homeBannersStore.dismissBanner(id: item.id, walletId: wallet.id)
        updateSectionHeight(remainingCount: remainingCount)
        updateSectionVisibility(isVisible: remainingCount > 0)
    }

    func handleBannersDisappeared() {
        shownBannerIDs.removeAll()
        clickedBannerIDs.removeAll()
    }

    func handleBannerShown(id: String) {
        guard shownBannerIDs.insert(id).inserted else { return }
        analyticsProvider.log(BannerView(bannerId: id))
    }

    private func handleBannerClick(id: String, action: BannerActionType) {
        guard clickedBannerIDs.insert(id).inserted else { return }
        analyticsProvider.log(BannerClick(bannerId: id, action: action))
    }

    private static func actionType(for deeplink: Deeplink?) -> BannerActionType {
        switch deeplink {
        case .battery: return .battery
        case .deposit: return .deposit
        case .withdraw: return .withdraw
        case .swap: return .swap
        case .staking, .pool: return .staking
        case .transfer: return .send
        case .trading, .tradeAsset: return .trade
        case .dapp, .browser: return .dapp
        default: return .other
        }
    }

    private func finishLoading() {
        setState(.loaded(visibleBannerItems()))
    }

    /// Neither a dismissal nor a store update is an answer: a reload still in flight keeps its
    /// phase, and a deck that has not asked for anything yet stays idle so it still asks.
    private func refreshBannerItems() {
        switch state {
        case .idle:
            return
        case let .loading(_, task):
            setState(.loading(data: visibleBannerItems(), task: task))
        case .loaded:
            setState(.loaded(visibleBannerItems()))
        }
    }

    private func visibleBannerItems() -> [BannerItem] {
        Array(homeBannersStore.visibleBanners(for: wallet).compactMap(mapBannerItem).reversed())
    }

    private func setState(_ state: HomeBannersViewState) {
        self.state = state
        updateSectionHeight(remainingCount: state.items.count)
        updateSectionVisibility(isVisible: !state.items.isEmpty)
    }

    private func updateSectionVisibility(isVisible: Bool) {
        guard isSectionVisible != isVisible else { return }
        isSectionVisible = isVisible
        onSectionVisibilityChanged?(isVisible)
    }

    private func updateSectionHeight(remainingCount: Int) {
        let sectionHeight = WalletBalanceHomeBannersLayout.height(remainingCount: remainingCount)
        guard self.sectionHeight != sectionHeight else { return }
        self.sectionHeight = sectionHeight
        onSectionHeightChanged?(sectionHeight)
    }

    private func mapBannerItem(_ banner: HomeBanner) -> BannerItem? {
        let action: (() -> Void)? = {
            guard let button = banner.button else { return nil }
            switch button.type {
            case let .deeplink(url):
                return { [weak self] in
                    guard let self else { return }
                    let deeplink = try? self.deeplinkParser.parse(string: url.absoluteString)
                    self.handleBannerClick(id: banner.id, action: Self.actionType(for: deeplink))
                    guard let deeplink else { return }
                    self.onOpenDeeplink?(deeplink)
                }
            case let .link(url):
                return { [weak self] in
                    guard let self else { return }
                    self.handleBannerClick(id: banner.id, action: .other)
                    self.onOpenLink?(url)
                }
            case .unknown:
                return nil
            }
        }()

        return BannerItem(
            id: banner.id,
            title: banner.title,
            description: banner.description,
            actionTitle: banner.button?.title ?? "",
            imageURL: banner.image,
            action: action
        )
    }
}
