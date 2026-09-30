import CoreGraphics
import Foundation
import KeeperCore
import TKCore
import TKUIKit

enum HomeBannersViewState {
    case idle
    case loading(data: [BannerItem]?, task: Task<Void, Never>)
    case loaded([BannerItem])

    var items: [BannerItem] {
        switch self {
        case .idle:
            []
        case let .loading(data, _):
            data ?? []
        case let .loaded(items):
            items
        }
    }

    var hasAnswered: Bool {
        switch self {
        case .idle:
            false
        case let .loading(data, _):
            data != nil
        case .loaded:
            true
        }
    }
}

@MainActor
final class WalletBalanceHomeBannersViewModel: ObservableObject {
    @Published private(set) var state: HomeBannersViewState = .idle
    @Published private(set) var sectionHeight: CGFloat
    @Published private(set) var isSectionVisible: Bool

    var onOpenDeeplink: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    var onOpenLink: ((URL) -> Void)?
    var onSectionVisibilityChanged: ((_ isVisible: Bool) -> Void)?
    var onSectionHeightChanged: ((_ height: CGFloat) -> Void)?

    private(set) var wallet: Wallet

    private var scopeWalletId: String? {
        wallet.multichainWalletState?.walletId
    }

    private let homeBannersStore: HomeBannersStore
    private let homeBannersLoader: HomeBannersLoader
    private let deeplinkParser: DeeplinkParser
    private let analyticsProvider: AnalyticsProvider

    private var shownBannerIDs = Set<String>()
    private var clickedBannerIDs = Set<String>()

    init(
        wallet: Wallet,
        walletsStore: WalletsStore,
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
        let cachedCount = homeBannersStore.visibleBanners(for: wallet).count
        sectionHeight = WalletBalanceHomeBannersLayout.height(remainingCount: cachedCount)
        isSectionVisible = cachedCount > 0

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

        walletsStore.addObserver(self) { observer, event in
            Task { @MainActor in
                observer.didGetWalletsStoreEvent(event)
            }
        }
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        switch event {
        case let .didUpdateWalletMetaData(wallet),
             let .didUpdateWalletMultichain(wallet):
            adopt(wallet: wallet)
        default:
            break
        }
    }

    private func adopt(wallet: Wallet) {
        guard self.wallet == wallet else { return }
        let previousScopeWalletId = scopeWalletId
        self.wallet = wallet
        guard previousScopeWalletId != scopeWalletId else { return }

        restart()
    }

    func startLoadIfNeeded() {
        guard case .idle = state else { return }
        startLoad()
    }

    func loadIfNeeded() async {
        startLoadIfNeeded()
        guard case let .loading(_, task) = state else { return }
        await task.value
    }

    private func restart() {
        if case let .loading(_, task) = state {
            task.cancel()
        }
        startLoad()
    }

    private func startLoad() {
        let cached = visibleBannerItems()
        let data: [BannerItem]? = cached.isEmpty ? nil : cached
        let loader = homeBannersLoader
        let scope = WalletScope.walletId(scopeWalletId)
        let task = Task { [weak self] in
            await loader.loadBanners(scope: scope, force: false)
            guard !Task.isCancelled else { return }
            self?.finishLoading()
        }
        setState(.loading(data: data, task: task))
    }

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

    private func refreshBannerItems() {
        switch state {
        case .idle:
            return
        case let .loading(data, task):
            guard data != nil else { return }
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
                    self.onOpenDeeplink?(deeplink, UtmParameters(link: url.absoluteString))
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
