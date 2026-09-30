import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import TronSwift
import UIKit

/// Presents the Mystery Raffle modal (active / over states) and routes its CTAs.
///
/// Deeplink-bearing rows (earn tasks, `.deeplink` CTAs, story buttons) are dispatched
/// through `openDeeplink`, which each of the presenting coordinators bubbles up to
/// `MainCoordinator.handleDeeplink`.
final class MysteryRaffleCoordinator: RouterCoordinator<ViewControllerRouter> {
    var didClose: (() -> Void)?

    /// `MysteryRaffleHostingViewController.viewDidLoad` reassigns the sheet's
    /// presentation delegate to itself, so the router's own `onDismiss` (registered
    /// in `openRaffle()`) never fires on an interactive swipe — the VC instead calls
    /// `didTapClose()` → `close()`. Guards every teardown path (`close()` and the
    /// CTA navigation methods) so a stray re-entrant call can't dismiss/tear down twice.
    private var hasLeft = false

    /// `MysteryRaffleContent`'s Kind/countdown mapping is time-derived (see
    /// `MysteryRaffleContent+Mapping.swift`), so re-map on a timer even when
    /// `RaffleStore` hasn't emitted — otherwise a boundary (e.g. the zero-fee
    /// window ending) passing while the sheet is open wouldn't update the layout.
    private static let refreshInterval: TimeInterval = 30
    private var refreshTimer: Timer?
    private weak var viewModel: MysteryRaffleViewModel?

    private var boundaryRefreshTask: Task<Void, Never>?
    private var boundaryRefreshTracker = MysteryRaffleBoundaryRefreshTracker()

    private var awaitingInitialContent = false
    private var initialContentTimeoutTask: Task<Void, Never>?
    private static let initialContentTimeout: UInt64 = 15 * NSEC_PER_SEC

    private let content: MysteryRaffleContent?
    private let raffleStore: RaffleStore
    /// Optional single-raffle filter (e.g. from a deeplink).
    private let raffleId: String?
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    /// Set when opened from the swap screen's own raffle promo — the swap CTA then
    /// just reveals that existing screen instead of stacking a second swap flow on
    /// top of it (see `handleGoToSwap`).
    private let presentedFromSwapFlow: Bool
    /// Where the modal was opened from — carried into `raffle_open`.
    private let source: RaffleSource
    /// Generic deeplink dispatch, bubbled from the presenting coordinator.
    private let openDeeplink: ((String) -> Void)?
    private let openMigration: ((@escaping () -> Void) -> Void)?

    /// The raffle currently rendered, kept for CTA routing.
    private var selectedRaffle: MultichainRaffle?

    /// `raffle_open` fires once per presentation, on the first resolved content.
    private var didLogOpen = false

    /// The raffle's stories are offered once per presentation, on the first resolved content.
    private var didOfferStory = false
    private var isSheetPresented = false
    private var pendingStoryRaffle: MultichainRaffle?

    init(
        content: MysteryRaffleContent?,
        selectedRaffle: MultichainRaffle?,
        raffleStore: RaffleStore,
        raffleId: String?,
        source: RaffleSource,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        presentedFromSwapFlow: Bool,
        openDeeplink: ((String) -> Void)?,
        openMigration: ((@escaping () -> Void) -> Void)?,
        router: ViewControllerRouter
    ) {
        self.content = content
        self.selectedRaffle = selectedRaffle
        self.raffleStore = raffleStore
        self.raffleId = raffleId
        self.source = source
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.presentedFromSwapFlow = presentedFromSwapFlow
        self.openDeeplink = openDeeplink
        self.openMigration = openMigration
        super.init(router: router)
    }

    deinit {
        refreshTimer?.invalidate()
        boundaryRefreshTask?.cancel()
        initialContentTimeoutTask?.cancel()
    }

    override func start() {
        openRaffle()
    }
}

extension MysteryRaffleCoordinator {
    /// Guards against presenting a second raffle modal on top of one already showing —
    /// `presentCurrent` is called from four independent coordinators (wallet entry
    /// point, trade banner, swap promo, main-screen deeplink), so the guard lives here
    /// rather than being duplicated per call site.
    private weak static var current: MysteryRaffleCoordinator?

    /// Set for as long as a CTA's migration/swap hand-off is in flight, independent of
    /// `current` — `current` is cleared as soon as the *sheet* is dismissed (so a fresh
    /// raffle sheet can still be opened), but a second concurrent hand-off from that
    /// fresh sheet would spawn a duplicate migration/swap flow, so it's guarded
    /// separately in `handleGoToMigration`/`handleGoToSwap`.
    private static var isFollowUpFlowActive = false

    @MainActor
    @discardableResult
    static func presentCurrent(
        from parent: Coordinator,
        rootViewController: UIViewController,
        source: RaffleSource,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        presentedFromSwapFlow: Bool = false,
        presentedFromBanner: Bool = false,
        openDeeplink: ((String) -> Void)? = nil,
        openMigration: ((@escaping () -> Void) -> Void)? = nil
    ) -> MysteryRaffleCoordinator? {
        let presentation = MysteryRafflePresentation(
            raffles: keeperCoreMainAssembly.storesAssembly.raffleStore.getState()
        )
        guard let presentation else { return nil }

        // The standalone banner exists to open a story (`RaffleBanner` in the contract), so
        // when its own button deeplinks to one, show that story instead of the modal. Only
        // the surfaces that actually render `raffle.banner` take this path — the wallet
        // entry point and the swap promo are separate components with their own CTA.
        if presentedFromBanner, presentBannerStoryIfNeeded(
            raffle: presentation.raffle,
            rootViewController: rootViewController,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            openDeeplink: openDeeplink
        ) {
            return nil
        }

        return present(
            raffle: presentation.raffle,
            from: parent,
            rootViewController: rootViewController,
            source: source,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            presentedFromSwapFlow: presentedFromSwapFlow,
            openDeeplink: openDeeplink,
            openMigration: openMigration
        )
    }

    @MainActor
    @discardableResult
    static func present(
        raffle: MultichainRaffle,
        from parent: Coordinator,
        rootViewController: UIViewController,
        source: RaffleSource,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        presentedFromSwapFlow: Bool = false,
        openDeeplink: ((String) -> Void)? = nil,
        openMigration: ((@escaping () -> Void) -> Void)? = nil
    ) -> MysteryRaffleCoordinator? {
        guard current == nil, !isFollowUpFlowActive else { return nil }

        let coordinator = MysteryRaffleCoordinator(
            content: MysteryRaffleContent(raffle: raffle),
            selectedRaffle: raffle,
            raffleStore: keeperCoreMainAssembly.storesAssembly.raffleStore,
            raffleId: raffle.id,
            source: source,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            presentedFromSwapFlow: presentedFromSwapFlow,
            openDeeplink: openDeeplink,
            openMigration: openMigration,
            router: ViewControllerRouter(rootViewController: rootViewController)
        )
        return launch(coordinator, from: parent)
    }

    @MainActor
    @discardableResult
    static func presentLoading(
        from parent: Coordinator,
        rootViewController: UIViewController,
        source: RaffleSource,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        openDeeplink: ((String) -> Void)? = nil,
        openMigration: ((@escaping () -> Void) -> Void)? = nil
    ) -> MysteryRaffleCoordinator? {
        guard current == nil, !isFollowUpFlowActive else { return nil }

        let coordinator = MysteryRaffleCoordinator(
            content: nil,
            selectedRaffle: nil,
            raffleStore: keeperCoreMainAssembly.storesAssembly.raffleStore,
            raffleId: nil,
            source: source,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            presentedFromSwapFlow: false,
            openDeeplink: openDeeplink,
            openMigration: openMigration,
            router: ViewControllerRouter(rootViewController: rootViewController)
        )
        coordinator.awaitingInitialContent = true
        return launch(coordinator, from: parent)
    }

    @MainActor
    private static func presentBannerStoryIfNeeded(
        raffle: MultichainRaffle,
        rootViewController: UIViewController,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        openDeeplink: ((String) -> Void)?
    ) -> Bool {
        guard
            current == nil,
            !isFollowUpFlowActive,
            let button = raffle.banner?.button,
            button.action == .deeplink
        else { return false }

        let storiesRouter = MysteryRaffleStoriesRouter.make(
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )
        guard let story = storiesRouter.story(forPayload: button.payload, in: raffle) else {
            return false
        }
        return storiesRouter.present(
            story: story,
            from: rootViewController,
            source: Self.bannerStoryAnalyticsSource,
            openDeeplink: openDeeplink
        )
    }

    /// Auto-opens the raffle's next unshown story on its own, with no modal underneath —
    /// the app-launch entry point. The raffle is only known once its wallet-scoped fetch
    /// answers, so callers drive this from `RaffleStore` rather than from `start()`.
    /// Returns whether a story was presented; `StoriesService` records it as shown, so it
    /// stays a once-per-story event across launches.
    @MainActor
    static func presentLaunchStory(
        raffles: [MultichainRaffle],
        rootViewController: UIViewController,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        openDeeplink: ((String) -> Void)?
    ) -> Bool {
        guard let presentation = MysteryRafflePresentation(
            raffles: raffles
        ) else { return false }

        return MysteryRaffleStoriesRouter
            .make(keeperCoreMainAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)
            .presentAutoOpenStories(
                in: presentation.raffle,
                from: rootViewController,
                source: launchStoryAnalyticsSource,
                openDeeplink: openDeeplink
            )
    }

    private static let bannerStoryAnalyticsSource = "raffle-banner"
    private static let launchStoryAnalyticsSource = "raffle-launch"
    private static let ctaStoryAnalyticsSource = "raffle-cta"
    private static let autoStoryAnalyticsSource = "raffle-auto"
    private static let debugStoryAnalyticsSource = "raffle-dev-menu"

    /// Presents `content` statically, with no store/loader — the dev-menu design-review
    /// surface previews mock states that have no backing `MultichainRaffle`, and a live
    /// backend update must not overwrite them.
    @MainActor
    static func presentStub(
        content: MysteryRaffleContent,
        rootViewController: UIViewController
    ) {
        let module = MysteryRaffleAssembly.module(content: content)
        module.output.onClose = { [weak viewController = module.view] in
            viewController?.dismiss(animated: true)
        }
        module.output.onPrimaryAction = { [weak viewController = module.view] in
            guard content.statusBadge == nil else { return }
            viewController?.dismiss(animated: true)
        }
        rootViewController.present(module.view, animated: true)
    }

    /// Opens one of the live raffle's stories from the dev menu, bypassing the shown-once
    /// bookkeeping the auto-open path respects.
    @MainActor
    static func presentStory(
        _ story: MultichainRaffleStory,
        rootViewController: UIViewController,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        openDeeplink: ((String) -> Void)?
    ) {
        MysteryRaffleStoriesRouter
            .make(keeperCoreMainAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)
            .present(
                story: story,
                from: rootViewController,
                source: debugStoryAnalyticsSource,
                openDeeplink: openDeeplink
            )
    }

    @MainActor
    private static func launch(
        _ coordinator: MysteryRaffleCoordinator,
        from parent: Coordinator
    ) -> MysteryRaffleCoordinator {
        coordinator.didClose = { [weak parent, weak coordinator] in
            if let coordinator, current === coordinator {
                Self.current = nil
            }
            parent?.removeChild(coordinator)
        }
        parent.addChild(coordinator)
        current = coordinator
        coordinator.start()
        return coordinator
    }
}

private extension MysteryRaffleCoordinator {
    func openRaffle() {
        let module = MysteryRaffleAssembly.module(content: content)
        let viewModel = module.input

        module.output.onClose = { [weak self] in
            self?.close()
        }

        module.output.onPrimaryAction = { [weak self] in
            self?.handlePrimaryAction()
        }

        // Only chevron (deeplink-bearing) rows are tappable (`RaffleEarnList.row(for:)`).
        module.output.onEarnTask = { [weak self] task in
            guard let self else { return }
            self.coreAssembly.analyticsProvider.log(RaffleClickTask(taskId: task.id))
            self.handleTask(id: task.id)
        }

        module.output.onMilestone = { [weak self] milestoneId in
            guard let self else { return }
            self.coreAssembly.analyticsProvider.log(RaffleClickMilestone(milestoneId: milestoneId))
            self.handleGoToSwap()
        }

        module.output.onGetMore = { [weak self] in
            guard let self else { return }
            self.coreAssembly.analyticsProvider.log(
                RaffleClickGetMore(
                    kind: self.currentAnalyticsKind,
                    ticketsTotal: self.selectedRaffle?.progress?.ticketsTotal ?? 0
                )
            )
        }

        self.viewModel = viewModel
        observeRaffles(store: raffleStore, viewModel: viewModel)
        apply(raffles: raffleStore.getState(), viewModel: viewModel)
        scheduleRefreshTimer()
        scheduleInitialContentTimeoutIfNeeded()

        router.present(
            module.view,
            completion: { [weak self] in
                guard let self else { return }
                isSheetPresented = true
                presentPendingStory()
            },
            onDismiss: { [weak self] in
                self?.didClose?()
            }
        )
    }

    func observeRaffles(store: RaffleStore, viewModel: MysteryRaffleViewModel) {
        store.addObserver(self) { [weak viewModel] coordinator, event in
            guard case let .didUpdateRaffles(raffles) = event else { return }
            Task { @MainActor in
                coordinator.apply(raffles: raffles, viewModel: viewModel)
            }
        }
    }

    func scheduleRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.apply(raffles: self.raffleStore.getState(), viewModel: self.viewModel)
            }
        }
    }

    func scheduleInitialContentTimeoutIfNeeded() {
        guard awaitingInitialContent else { return }
        initialContentTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.initialContentTimeout)
            guard !Task.isCancelled, let self, self.awaitingInitialContent else { return }
            self.awaitingInitialContent = false
            self.apply(raffles: self.raffleStore.getState(), viewModel: self.viewModel)
        }
    }

    @MainActor
    func apply(raffles: [MultichainRaffle], viewModel: MysteryRaffleViewModel?) {
        guard let raffle = selectRaffle(from: raffles) else {
            guard !awaitingInitialContent else { return }
            // No raffle left to show (e.g. active wallet switched to one with none,
            // or a re-fetch came back empty) — don't leave the sheet stuck on stale data.
            close()
            return
        }
        awaitingInitialContent = false
        initialContentTimeoutTask?.cancel()
        initialContentTimeoutTask = nil
        selectedRaffle = raffle
        viewModel?.update(content: MysteryRaffleContent(raffle: raffle))
        logOpenIfNeeded(raffle: raffle)
        offerStoryIfNeeded(for: raffle)
        maybeScheduleBoundaryRefresh(for: raffle)
    }

    /// Auto-opens the raffle's not-yet-shown stories over the modal, once per presentation —
    /// `apply` re-runs on every store emission and refresh tick. `StoriesService` marks each
    /// one shown, so they won't reappear on the next open.
    ///
    /// Content usually resolves before the sheet finishes presenting, so the stories wait
    /// for that instead of racing the sheet's own transition.
    private func offerStoryIfNeeded(for raffle: MultichainRaffle) {
        guard !didOfferStory, !hasLeft else { return }
        didOfferStory = true
        guard isSheetPresented else {
            pendingStoryRaffle = raffle
            return
        }
        presentAutoOpenStories(in: raffle)
    }

    private func presentPendingStory() {
        guard let raffle = pendingStoryRaffle, !hasLeft else { return }
        pendingStoryRaffle = nil
        presentAutoOpenStories(in: raffle)
    }

    private func presentAutoOpenStories(in raffle: MultichainRaffle) {
        storiesRouter.presentAutoOpenStories(
            in: raffle,
            from: router.rootViewController,
            source: Self.autoStoryAnalyticsSource,
            openDeeplink: storyDeeplinkAction
        )
    }

    private var storiesRouter: MysteryRaffleStoriesRouter {
        MysteryRaffleStoriesRouter.make(
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )
    }

    /// Stories are presented in their own window (`StoriesPresenter`), so the raffle modal
    /// stays underneath until a story action routes away from it.
    private func present(story: MultichainRaffleStory, source: String) -> Bool {
        storiesRouter.present(
            story: story,
            from: router.rootViewController,
            source: source,
            openDeeplink: storyDeeplinkAction
        )
    }

    private var storyDeeplinkAction: ((String) -> Void)? {
        guard openDeeplink != nil else { return nil }
        return { [weak self] deeplink in
            self?.openExternalDeeplink(deeplink)
        }
    }

    /// Fires `raffle_open` once, on the first resolved content — `apply` re-runs on every
    /// store emission / refresh tick, so guard against duplicate opens.
    private func logOpenIfNeeded(raffle: MultichainRaffle) {
        guard !didLogOpen else { return }
        didLogOpen = true
        coreAssembly.analyticsProvider.log(
            RaffleOpen(
                source: source,
                kind: Self.analyticsKind(for: raffle),
                ticketsTotal: raffle.progress?.ticketsTotal ?? 0,
                prize: raffle.status == .won ? raffle.progress?.winningPrize?.title : nil
            )
        )
    }

    /// Analytics kind of the currently rendered raffle; defaults to `.active` before any
    /// content resolves (get-more is only reachable next to earn-ticket sections anyway).
    private var currentAnalyticsKind: RaffleKind {
        selectedRaffle.map(Self.analyticsKind(for:)) ?? .active
    }

    private func maybeScheduleBoundaryRefresh(for raffle: MultichainRaffle) {
        let now = RaffleClock.now
        var boundaries: [MysteryRaffleBoundaryRefreshTracker.DatedBoundary] = [(.startsAt, raffle.startsAt)]
        if let zeroFeeEndsAt = raffle.progress?.zeroFeeEndsAt {
            boundaries.append((.zeroFeeEndsAt, zeroFeeEndsAt))
        }
        boundaries.append((.endsAt, raffle.endsAt))
        if let prizesRevealAt = raffle.prizesRevealAt {
            boundaries.append((.prizesReveal, prizesRevealAt))
        }

        guard boundaryRefreshTracker.shouldRefresh(raffleId: raffle.id, boundaries: boundaries, now: now) else { return }
        scheduleBoundaryRefresh()
    }

    private func scheduleBoundaryRefresh() {
        boundaryRefreshTask?.cancel()
        boundaryRefreshTask = Task { @MainActor [weak self] in
            let delay = TimeInterval.random(in: 0 ... 30)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            guard
                let wallet = try? self.keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
                case let .multichain(multichainState) = wallet.multichain
            else { return }
            self.keeperCoreMainAssembly.loadersAssembly.raffleLoader.loadRaffles(
                walletId: multichainState.walletId,
                lang: Locale.current.languageCode ?? "en",
                ids: nil
            )
        }
    }

    /// Picks the raffle to render: the deeplinked id when set, otherwise the first.
    func selectRaffle(from raffles: [MultichainRaffle]) -> MultichainRaffle? {
        if let raffleId {
            return raffles.first { $0.id == raffleId }
        }
        return MysteryRafflePresentation.selectRaffle(from: raffles)
    }

    func handlePrimaryAction() {
        let route = Self.ctaRoute(for: selectedRaffle?.cta, deeplinkParser: keeperCoreMainAssembly.deeplinkParser)

        if let analyticsAction = route.analyticsAction {
            coreAssembly.analyticsProvider.log(
                RaffleClickCta(
                    action: analyticsAction,
                    kind: currentAnalyticsKind,
                    ticketsTotal: selectedRaffle?.progress?.ticketsTotal ?? 0
                )
            )
        }

        if handleAsStory(cta: selectedRaffle?.cta) {
            return
        }

        switch route {
        case .migrate:
            handleGoToMigration()
        case .swap:
            handleGoToSwap()
        case .resultsLink:
            handleGoToResults()
        case let .deeplink(payload):
            guard openDeeplink != nil else { return handleGoToSwap() }
            openExternalDeeplink(payload)
        }
    }

    /// A `.deeplink` CTA whose payload names one of the raffle's own stories opens that
    /// story instead of routing anywhere — keeps the sheet open underneath.
    func handleAsStory(cta: MultichainRaffleCTA?) -> Bool {
        guard !hasLeft, let cta, cta.action == .deeplink, let raffle = selectedRaffle else {
            return false
        }
        guard let story = storiesRouter.story(forPayload: cta.payload, in: raffle) else {
            return false
        }
        return present(story: story, source: Self.ctaStoryAnalyticsSource)
    }

    /// Routes a tapped earn task to its own `deeplink` when the backend sent one, falling
    /// back to the qualifying swap for tasks that carry none.
    func handleTask(id: String) {
        guard !hasLeft else { return }
        guard
            let task = selectedRaffle?.tasks.first(where: { $0.id == id }),
            let deeplink = task.deeplink
        else {
            handleGoToSwap()
            return
        }
        if let raffle = selectedRaffle, let story = storiesRouter.story(forPayload: deeplink, in: raffle) {
            if present(story: story, source: Self.ctaStoryAnalyticsSource) {
                return
            }
        }
        guard openDeeplink != nil else {
            return handleGoToSwap()
        }
        openTaskDeeplink(deeplink)
    }

    /// A task that routes to wallet import pays the wallet it was started from, so the source
    /// wallet is pinned before the flow leaves — the import switches the active wallet. The
    /// deeplink waits on that write: the import itself can otherwise land first.
    private func openTaskDeeplink(_ deeplink: String) {
        guard
            case .addWallet? = try? keeperCoreMainAssembly.deeplinkParser.parse(string: deeplink),
            let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
            case let .multichain(state) = wallet.multichain
        else {
            openExternalDeeplink(deeplink)
            return
        }
        let reporter = keeperCoreMainAssembly.multichainAssembly.raffleImportReporter
        Task { @MainActor [weak self] in
            await reporter.beginImport(sourceWalletId: state.walletId)
            self?.openExternalDeeplink(deeplink)
        }
    }

    /// `.won`/`.lost` CTA points at an external results page (e.g. Telegram) via
    /// `cta.payload`; a `.deeplink` payload goes through the generic dispatch.
    func handleGoToResults() {
        guard !hasLeft else { return }
        guard let cta = selectedRaffle?.cta else {
            close()
            return
        }
        switch cta.action {
        case .link:
            defer { close() }
            guard let url = URL(string: cta.payload) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        case .deeplink:
            guard openDeeplink != nil else {
                close()
                return
            }
            openExternalDeeplink(cta.payload)
        }
    }

    func openExternalDeeplink(_ deeplink: String) {
        guard !hasLeft, let openDeeplink else { return }
        markLeft()
        router.dismiss { [weak self] in
            openDeeplink(deeplink)
            self?.didClose?()
        }
    }

    func handleGoToMigration() {
        guard !hasLeft else { return }
        guard !Self.isFollowUpFlowActive else {
            close()
            return
        }
        guard
            let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
            wallet.isMultichain,
            let openMigration
        else {
            close()
            return
        }
        markLeft()
        Self.isFollowUpFlowActive = true

        router.dismiss { [weak self] in
            openMigration {
                Self.isFollowUpFlowActive = false
                self?.didClose?()
            }
        }
    }

    /// Qualifying trade for raffle tickets is TON → USDT (TRON) — pin that pair via
    /// `initialSelection` rather than the swap screen's own TON/ETH default. When
    /// already opened from the swap screen's own promo, the underlying screen *is*
    /// that swap flow, so just reveal it instead of stacking a second one on top.
    func handleGoToSwap() {
        guard !hasLeft else { return }
        guard !presentedFromSwapFlow, !Self.isFollowUpFlowActive else {
            close()
            return
        }
        guard
            let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
            case let .multichain(multichainState) = wallet.multichain
        else {
            close()
            return
        }
        markLeft()
        Self.isFollowUpFlowActive = true

        let swapNavigationController = TKNavigationController()
        swapNavigationController.configureDefaultAppearance()
        swapNavigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = MultichainSwapCoordinator(
            wallet: wallet,
            multichainState: multichainState,
            nativeSwapContext: NativeSwapContext(),
            initialSelection: Self.ticketSwapAssetSelection,
            initiatedBy: .user,
            router: NavigationControllerRouter(rootViewController: swapNavigationController),
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        coordinator.didRequestDeeplinkHandling = openDeeplink

        // `didFinish` (explicit back/close inside the swap flow, which dismisses
        // `swapNavigationController` programmatically) and the router's `onDismiss`
        // below (interactive swipe on the sheet) are mutually exclusive triggers for
        // the same modal — but only one of them used to run any teardown at all, so an
        // interactive swipe left `isFollowUpFlowActive` stuck `true` forever and this
        // coordinator/its swap child leaked as `current`'s parent's children, silently
        // disabling every raffle entry point in the app until restart. Funnel both
        // through the same guarded cleanup instead.
        var isSwapHandOffFinished = false
        let finishSwapHandOff: () -> Void = { [weak self, weak coordinator] in
            guard !isSwapHandOffFinished else { return }
            isSwapHandOffFinished = true
            Self.isFollowUpFlowActive = false
            self?.removeChild(coordinator)
            self?.didClose?()
        }

        coordinator.didFinish = { [weak swapNavigationController] _ in
            swapNavigationController?.dismiss(animated: true)
            finishSwapHandOff()
        }
        addChild(coordinator)
        coordinator.start()

        let presentingRouter = router
        router.dismiss {
            presentingRouter.present(
                swapNavigationController,
                onDismiss: finishSwapHandOff
            )
        }
    }

    static let ticketSwapAssetSelection = MultichainSwapInitialAssetSelection(
        assetId: "tron/mainnet/trc20/\(TronSwift.USDT.address.base58)",
        side: .receive
    )

    func close() {
        guard !hasLeft else { return }
        markLeft()
        router.dismiss(completion: { [weak self] in
            self?.didClose?()
        })
    }

    /// Marks the sheet as gone for good. Clears the `current` guard here — rather than
    /// waiting for `didClose` — because after routing to migration/swap this coordinator
    /// deliberately stays alive (as the new flow's parent) until that flow finishes;
    /// a fresh raffle sheet can still open in the meantime (`isFollowUpFlowActive`,
    /// not `current`, is what blocks a second concurrent hand-off).
    func markLeft() {
        hasLeft = true
        refreshTimer?.invalidate()
        refreshTimer = nil
        boundaryRefreshTask?.cancel()
        boundaryRefreshTask = nil
        initialContentTimeoutTask?.cancel()
        initialContentTimeoutTask = nil
        if Self.current === self {
            Self.current = nil
        }
    }
}

struct MysteryRaffleBoundaryRefreshTracker {
    enum Boundary: Hashable {
        case startsAt
        case zeroFeeEndsAt
        case endsAt
        case prizesReveal
    }

    typealias DatedBoundary = (kind: Boundary, date: Date)

    private var raffleId: String?
    private var refreshedDates: [Boundary: Date] = [:]

    mutating func shouldRefresh(raffleId: String, boundaries: [DatedBoundary], now: Date) -> Bool {
        if self.raffleId != raffleId {
            self.raffleId = raffleId
            refreshedDates.removeAll()
        }

        let currentBoundaries = Set(boundaries.map(\.kind))
        refreshedDates = refreshedDates.filter { currentBoundaries.contains($0.key) }

        let crossed = boundaries.filter {
            now >= $0.date && refreshedDates[$0.kind] != $0.date
        }
        for boundary in crossed {
            refreshedDates[boundary.kind] = boundary.date
        }
        return !crossed.isEmpty
    }
}

extension MysteryRaffleCoordinator {
    /// The rendered layout no longer branches on a phase, but the funnel still separates
    /// the launch modal from the live raffle — for a wallet that hasn't reached the results
    /// yet, a payload without prizes and milestones is the former. An ended raffle
    /// awaiting its reveal is section-less for the same reason a results payload is, so it
    /// stays with the live raffle rather than falling back into the launch funnel.
    nonisolated static func analyticsKind(for raffle: MultichainRaffle) -> RaffleKind {
        switch raffle.status {
        case .won:
            return .won
        case .lost:
            return .lost
        case .endedPending:
            return .active
        case .notJoined, .joined:
            return raffle.isMigrationPhase ? .migration : .active
        }
    }

    enum CtaRoute: Equatable {
        case migrate
        case swap
        case resultsLink
        case deeplink(String)

        var analyticsAction: RaffleCtaAction? {
            switch self {
            case .migrate: return .migrate
            case .swap: return .swap
            case .resultsLink: return .resultsLink
            case .deeplink: return nil
            }
        }
    }

    nonisolated static func ctaRoute(for cta: MultichainRaffleCTA?, deeplinkParser: DeeplinkParser) -> CtaRoute {
        guard let cta else { return .swap }
        guard cta.action == .deeplink else { return .resultsLink }
        switch try? deeplinkParser.parse(string: cta.payload) {
        case .migration:
            return .migrate
        case .swap:
            return .swap
        case .none:
            return .swap
        default:
            return .deeplink(cta.payload)
        }
    }
}
