import Stories
import UIKit

/// The loading half of `StoriesController` the boot sequence needs, as a seam: the concrete
/// controller can only be built by the stories assembly, which the sequencing tests have no
/// use for.
protocol BootConfigurationStoriesLoading {
    func autoplayStories(walletId: String?) async -> [Stories.Story]
    func loadStory(storyId: String, ignoreShowed: Bool, walletId: String?) async -> Result<Stories.Story, Stories.StoriesController.Error>
}

extension Stories.StoriesController: BootConfigurationStoriesLoading {}

final class MainCoordinatorStoriesController {
    var fromViewControllerProvider: (() -> UIViewController?)?
    var deeplinkAction: ((String) -> Void)?
    var urlAction: ((URL) -> Void)?

    private let storiesPresenter: RaffleStoryPresenting
    private let storiesController: BootConfigurationStoriesLoading
    private var bootConfigurationStoriesRunID = 0
    /// The run that still owes a `completion`, if any. Cancellation is a no-op without one —
    /// the coordinator cancels on every deeplink it handles, and an unguarded cancel would take
    /// down whatever story happened to be on screen at the time.
    private var activeBootConfigurationStoriesRunID: Int?

    init(
        storiesPresenter: RaffleStoryPresenting,
        storiesController: BootConfigurationStoriesLoading
    ) {
        self.storiesPresenter = storiesPresenter
        self.storiesController = storiesController
    }

    /// Plays the boot configuration's autoplay stories back to back: `StoriesPresenter` owns a
    /// single window, so each story is started from the previous one's dismissal.
    ///
    /// `didPresentStory` reports each story the moment it goes on screen, which is a turn
    /// before `StoriesService` records it as shown.
    ///
    /// `completion` runs exactly once, on every path. `didComplete` is false when the run
    /// ended early — a page button routed the user somewhere, or the surface to present from
    /// went away — so the caller can tell "the sequence is over" from "don't put anything on
    /// top of where the user just landed".
    @MainActor
    func runBootConfigurationStories(
        walletId: String?,
        didPresentStory: @escaping (String) -> Void,
        completion: @escaping (_ didComplete: Bool) -> Void
    ) {
        let runID = startBootConfigurationStoriesRun()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let stories = await storiesController.autoplayStories(walletId: walletId)
            guard runID == bootConfigurationStoriesRunID else {
                finishBootConfigurationStoriesRun(runID: runID, didComplete: false, completion: completion)
                return
            }
            presentBootConfigurationStories(
                stories[...],
                runID: runID,
                didPresentStory: didPresentStory,
                completion: completion
            )
        }
    }

    @MainActor
    func presentBootConfigurationStories(
        stories: [Stories.Story],
        didPresentStory: @escaping (String) -> Void,
        completion: @escaping (_ didComplete: Bool) -> Void
    ) {
        presentBootConfigurationStories(
            stories[...],
            runID: startBootConfigurationStoriesRun(),
            didPresentStory: didPresentStory,
            completion: completion
        )
    }

    /// Stops the run where it stands and takes the story on screen down with it: something else
    /// is taking over the launch, and the sequence advances on user dismissals rather than on
    /// suspension points, so `Task` cancellation can't unwind it.
    @MainActor
    func cancelBootConfigurationStories() {
        guard activeBootConfigurationStoriesRunID != nil else { return }
        activeBootConfigurationStoriesRunID = nil
        bootConfigurationStoriesRunID &+= 1
        storiesPresenter.dismissCurrentStory()
    }

    @MainActor
    private func startBootConfigurationStoriesRun() -> Int {
        bootConfigurationStoriesRunID &+= 1
        activeBootConfigurationStoriesRunID = bootConfigurationStoriesRunID
        return bootConfigurationStoriesRunID
    }

    @MainActor
    private func finishBootConfigurationStoriesRun(
        runID: Int,
        didComplete: Bool,
        completion: (_ didComplete: Bool) -> Void
    ) {
        if activeBootConfigurationStoriesRunID == runID {
            activeBootConfigurationStoriesRunID = nil
        }
        completion(didComplete)
    }

    @MainActor
    private func presentBootConfigurationStories(
        _ stories: ArraySlice<Stories.Story>,
        runID: Int,
        didPresentStory: @escaping (String) -> Void,
        completion: @escaping (_ didComplete: Bool) -> Void
    ) {
        guard let story = stories.first else {
            finishBootConfigurationStoriesRun(runID: runID, didComplete: true, completion: completion)
            return
        }
        let remainingStories = stories.dropFirst()

        // Every step gets a task of its own, which also keeps the next presentation out of the
        // previous dismissal's teardown.
        Task { @MainActor [weak self] in
            guard let self else {
                completion(false)
                return
            }
            guard runID == bootConfigurationStoriesRunID,
                  let fromViewController = fromViewControllerProvider?()
            else {
                finishBootConfigurationStoriesRun(runID: runID, didComplete: false, completion: completion)
                return
            }
            let didPresent = storiesPresenter.presentStory(
                story: story,
                fromViewController: fromViewController,
                fromAnalyticsProperty: "wallet",
                deeplinkAction: { [weak self] in
                    self?.deeplinkAction?($0)
                },
                urlAction: { [weak self] in
                    self?.urlAction?($0)
                },
                onDismiss: { [weak self] reason in
                    guard let self else {
                        completion(false)
                        return
                    }
                    guard reason == .completed else {
                        finishBootConfigurationStoriesRun(runID: runID, didComplete: false, completion: completion)
                        return
                    }
                    Task { @MainActor [weak self] in
                        guard let self else {
                            completion(false)
                            return
                        }
                        guard runID == bootConfigurationStoriesRunID else {
                            finishBootConfigurationStoriesRun(runID: runID, didComplete: false, completion: completion)
                            return
                        }
                        presentBootConfigurationStories(
                            remainingStories,
                            runID: runID,
                            didPresentStory: didPresentStory,
                            completion: completion
                        )
                    }
                }
            )
            guard didPresent else {
                presentBootConfigurationStories(
                    remainingStories,
                    runID: runID,
                    didPresentStory: didPresentStory,
                    completion: completion
                )
                return
            }
            didPresentStory(story.id)
        }
    }

    @MainActor
    func handleDeeplinkStory(storyId: String, walletId: String?) async throws {
        guard let fromViewController = fromViewControllerProvider?() else { return }
        let result = await storiesController.loadStory(storyId: storyId, ignoreShowed: true, walletId: walletId)
        switch result {
        case let .success(story):
            storiesPresenter.presentStory(
                story: story,
                fromViewController: fromViewController,
                fromAnalyticsProperty: "deep-link",
                deeplinkAction: { [weak self] in
                    self?.deeplinkAction?($0)
                }, urlAction: { [weak self] in
                    self?.urlAction?($0)
                },
                onDismiss: nil
            )
        case let .failure(error):
            throw error
        }
    }
}
