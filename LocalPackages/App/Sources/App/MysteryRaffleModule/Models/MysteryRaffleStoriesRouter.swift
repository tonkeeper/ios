import KeeperCore
import Stories
import TKCore
import UIKit

/// The one presenter call the raffle stories need, as a seam: building the concrete
/// `StoriesPresenter` takes the whole stories assembly, which the auto-open sequencing
/// tests have no use for.
@MainActor
protocol RaffleStoryPresenting: AnyObject {
    @discardableResult
    func presentStory(
        story: Stories.Story,
        fromViewController: UIViewController,
        fromAnalyticsProperty: String,
        deeplinkAction: @escaping (String) -> Void,
        urlAction: @escaping (URL) -> Void,
        onDismiss: ((Stories.StoriesPresenter.DismissReason) -> Void)?
    ) -> Bool

    func dismissCurrentStory()
}

extension Stories.StoriesPresenter: RaffleStoryPresenting {}

/// Presents raffle stories through the shared stories UI.
///
/// Raffle stories arrive inline with the raffle (`Raffle.stories`) instead of the stories
/// endpoint, so `StoriesController`/`StoriesService` loading is bypassed and only the
/// presenter and the shown-once bookkeeping are reused.
@MainActor
final class MysteryRaffleStoriesRouter {
    /// `StoriesPresenter` owns the window the story is shown in and releases it on dismiss,
    /// so one long-lived instance is enough — and it must outlive whichever raffle surface
    /// triggered the story (a banner tap presents no coordinator at all). Keyed by the
    /// assembly it was built from, so a rebuilt main assembly (e.g. after logout) doesn't
    /// leave the presenter holding the previous session's stores.
    /// Held weakly and compared by identity: an `ObjectIdentifier` of a released assembly
    /// can be handed to the next allocation at the same address, which would match here and
    /// keep the stale router alive.
    private static var shared: MysteryRaffleStoriesRouter?
    private weak static var sharedAssembly: KeeperCore.MainAssembly?

    private let storiesPresenter: RaffleStoryPresenting
    private let storiesService: Stories.StoriesService

    /// Stories already handed to an auto-open path this session.
    private var claimedStoryIds: Set<String> = []
    private var isAutoOpenRunning = false

    init(
        storiesPresenter: RaffleStoryPresenting,
        storiesService: Stories.StoriesService
    ) {
        self.storiesPresenter = storiesPresenter
        self.storiesService = storiesService
    }

    static func make(
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> MysteryRaffleStoriesRouter {
        if let shared, sharedAssembly === keeperCoreMainAssembly {
            return shared
        }
        let assembly = Stories.Assembly(
            keeperCoreAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )
        let router = MysteryRaffleStoriesRouter(
            storiesPresenter: assembly.storiesPresenter(),
            storiesService: assembly.storiesService()
        )
        shared = router
        sharedAssembly = keeperCoreMainAssembly
        return router
    }

    /// The story a `.deeplink` CTA points at, if any. The backend doesn't spell out the
    /// payload → story link, so both shapes seen in practice are accepted: the bare story
    /// id and a deeplink carrying it as the last path component or an `id` query item.
    /// Anything else is left to the generic deeplink dispatch.
    nonisolated static func story(forPayload payload: String, in raffle: MultichainRaffle) -> MultichainRaffleStory? {
        guard !raffle.stories.isEmpty else { return nil }
        if let story = raffle.stories.first(where: { $0.id == payload }) {
            return story
        }
        guard let components = URLComponents(string: payload) else { return nil }
        let candidates = [
            components.queryItems?.first { $0.name == "id" }?.value,
            components.path.split(separator: "/").last.map(String.init),
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let story = raffle.stories.first(where: { $0.id == candidate }) {
                return story
            }
        }
        return nil
    }

    func story(forPayload payload: String, in raffle: MultichainRaffle) -> MultichainRaffleStory? {
        Self.story(forPayload: payload, in: raffle)
    }

    func excludeAutoOpenStoryIDs(_ storyIDs: Set<String>) {
        claimedStoryIds.formUnion(storyIDs)
    }

    /// The next story this wallet hasn't been shown yet — the auto-open candidate, claimed
    /// on the way out. The backend's own order is the sequence; repeated opens step through
    /// the set.
    ///
    /// `StoriesService` only records a story as shown once its presentation animation
    /// finishes, so without the claim the two auto-open paths (app launch and the raffle
    /// sheet) resolving the same store emission would both pick it and stack two story
    /// windows over one another.
    func claimAutoOpenStory(in raffle: MultichainRaffle) -> MultichainRaffleStory? {
        guard let story = raffle.stories.first(where: {
            !$0.pages.isEmpty
                && !claimedStoryIds.contains($0.id)
                && storiesService.isNeedToShow(storyID: $0.id)
        }) else { return nil }
        claimedStoryIds.insert(story.id)
        return story
    }

    /// Auto-opens every story this wallet hasn't seen yet, back to back: the raffle can
    /// carry several at once, and `StoriesPresenter` owns a single window, so each one is
    /// started from the previous one's dismissal. Tapping a page button ends the run — the
    /// user is being routed somewhere, and the stories left stay unclaimed for the next
    /// auto-open. Returns whether anything was opened.
    ///
    /// A run in flight wins: the other auto-open path (launch vs. raffle sheet) resolving
    /// the same store emission would otherwise replace the visible story's window.
    @discardableResult
    func presentAutoOpenStories(
        in raffle: MultichainRaffle,
        from viewController: UIViewController,
        source: String,
        openDeeplink: ((String) -> Void)?
    ) -> Bool {
        guard !isAutoOpenRunning, let story = claimAutoOpenStory(in: raffle) else { return false }
        isAutoOpenRunning = true
        return presentAutoOpen(story: story, in: raffle, from: viewController, source: source, openDeeplink: openDeeplink)
    }

    @discardableResult
    private func presentAutoOpen(
        story: MultichainRaffleStory,
        in raffle: MultichainRaffle,
        from viewController: UIViewController,
        source: String,
        openDeeplink: ((String) -> Void)?
    ) -> Bool {
        let didPresent = present(
            story: story,
            from: viewController,
            source: source,
            openDeeplink: openDeeplink
        ) { [weak self, weak viewController] reason in
            guard let self else { return }
            guard
                reason == .completed,
                let viewController,
                let next = claimAutoOpenStory(in: raffle)
            else {
                isAutoOpenRunning = false
                return
            }
            // The callback lands inside the dismissal transition's own teardown, which is
            // also where the presenter releases the story window — start the next one on
            // the following turn rather than inside it.
            Task { @MainActor [weak self, weak viewController] in
                guard let self else { return }
                guard let viewController else {
                    isAutoOpenRunning = false
                    return
                }
                presentAutoOpen(story: next, in: raffle, from: viewController, source: source, openDeeplink: openDeeplink)
            }
        }
        if !didPresent {
            // Nothing was shown and `StoriesService` recorded nothing, so give the claim
            // back instead of burning the story for the session.
            claimedStoryIds.remove(story.id)
            isAutoOpenRunning = false
        }
        return didPresent
    }

    /// QA: drops the shown-once bookkeeping (app-wide — the repository is shared with the
    /// regular stories) so the auto-open paths fire again without a reinstall.
    /// `isAutoOpenRunning` is cleared too: it only unwinds on a reported dismissal, so a run
    /// whose presentation never reports one would otherwise block auto-open for the session.
    func resetShownStories() {
        claimedStoryIds.removeAll()
        isAutoOpenRunning = false
        storiesService.resetShownStories()
    }

    @discardableResult
    func present(
        story: MultichainRaffleStory,
        from viewController: UIViewController,
        source: String,
        openDeeplink: ((String) -> Void)?,
        onDismiss: ((Stories.StoriesPresenter.DismissReason) -> Void)? = nil
    ) -> Bool {
        storiesPresenter.presentStory(
            story: Stories.Story(story: story),
            fromViewController: viewController,
            fromAnalyticsProperty: source,
            deeplinkAction: { payload in
                openDeeplink?(payload)
            },
            urlAction: { url in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            },
            onDismiss: onDismiss
        )
    }
}

private extension Stories.Story {
    init(story: MultichainRaffleStory) {
        self.init(
            id: story.id,
            pages: story.pages.map { page in
                Stories.Story.Page(
                    title: page.title,
                    description: page.description,
                    image: URL(string: page.image),
                    // The stories UI renders a single button per page; the contract allows
                    // several, so the first one wins.
                    button: page.buttons.first.map { button in
                        Stories.Story.Page.Button(
                            title: button.title,
                            payload: button.payload,
                            type: button.action == .deeplink ? .deeplink : .link
                        )
                    }
                )
            }
        )
    }
}
