import KeeperCore
import SafariServices
import TKCore
import TKFeatureFlags
import TKStories
import TKUIKit
import UIKit

@MainActor
public final class StoriesPresenter {
    private var window: UIWindow?
    private var storiesViewController: TKStories.StoriesViewController?

    private let storiesService: StoriesService
    private let storiesStore: StoriesStore
    private let walletsStore: WalletsStore
    private let analyticsProvider: AnalyticsProvider
    private let configuration: Configuration
    private let deeplinkParser: DeeplinkParser

    init(
        storiesService: StoriesService,
        storiesStore: StoriesStore,
        walletsStore: WalletsStore,
        analyticsProvider: AnalyticsProvider,
        configuration: Configuration,
        deeplinkParser: DeeplinkParser
    ) {
        self.storiesService = storiesService
        self.storiesStore = storiesStore
        self.walletsStore = walletsStore
        self.analyticsProvider = analyticsProvider
        self.configuration = configuration
        self.deeplinkParser = deeplinkParser
    }

    /// How a presented story went away — a caller chaining stories advances only after
    /// natural completion; an explicit close or action ends the chain.
    public enum DismissReason {
        case completed
        case closed
        case action
        case lastPageButton
    }

    /// Returns whether the story was actually presented — it is dropped when the app has no
    /// wallet/scene to present from or stories are switched off remotely, and a caller
    /// chaining stories has to unwind rather than wait for a dismissal that won't come.
    @MainActor
    @discardableResult
    public func presentStory(
        story: Story,
        fromViewController: UIViewController,
        fromAnalyticsProperty: String,
        isClosable: Bool = true,
        deeplinkAction: @escaping (String) -> Void,
        urlAction: @escaping (URL) -> Void,
        onDismiss: ((DismissReason) -> Void)? = nil
    ) -> Bool {
        guard !story.pages.isEmpty else { return false }
        guard window == nil || storiesViewController?.isModalInPresentation != true else { return false }
        guard let wallet = try? self.walletsStore.activeWallet else { return false }
        guard !configuration.flag(\.storiesDisabled, network: wallet.network) else { return false }
        guard let windowScene = fromViewController.windowScene else { return false }
        let window = createWindow(windowScene: windowScene)
        self.window = window

        let backgroundURLs = story.pages.compactMap { $0.image }
        ImagePrefetcherService().prefetch(urls: backgroundURLs)

        // Recorded at tap time: `deeplinkAction`/`urlAction` only run in the dismissal
        // completion, which UIKit invokes after the presentation controller's own callback.
        var dismissReason = DismissReason.closed

        let models: [StoriesPageModel] = story.pages.enumerated().map { [weak self] index, page in
            var button: StoriesPageModel.Button?
            if let pageButton = page.button, isClosable || index == story.pages.count - 1 {
                button = StoriesPageModel.Button(
                    title: pageButton.title,
                    action: { [weak self] in
                        dismissReason = index == story.pages.count - 1 ? .lastPageButton : .action
                        switch pageButton.type {
                        case .deeplink:
                            self?.storiesViewController?.dismiss(animated: true, completion: {
                                deeplinkAction(pageButton.payload)
                            })
                        case .link:
                            self?.storiesViewController?.dismiss(animated: true, completion: {
                                guard let url = URL(string: pageButton.payload) else { return }
                                urlAction(url)
                            })
                        }
                        self?.analyticsProvider.log(
                            eventKey: .storyClick,
                            args: ["story_id": story.id,
                                   "page_number": index + 1,
                                   "button_type": pageButton.type.rawValue,
                                   "button_payload": pageButton.payload,
                                   "button_title": pageButton.title]
                        )
                    }
                )
            }

            let links = page.links.map { link in
                StoriesPageModel.Link(
                    text: link.text,
                    action: { [weak self] in
                        guard let self else { return }
                        let isWebPage = ["http", "https"].contains(link.url.scheme?.lowercased())
                            && (try? deeplinkParser.parse(string: link.url.absoluteString)) == nil
                        guard isWebPage else {
                            guard isClosable else { return }
                            dismissReason = .action
                            storiesViewController?.dismiss(animated: true, completion: {
                                deeplinkAction(link.url.absoluteString)
                            })
                            return
                        }
                        let safariViewController = SFSafariViewController(url: link.url)
                        safariViewController.modalPresentationStyle = .fullScreen
                        storiesViewController?.present(safariViewController, animated: true)
                    }
                )
            }

            return StoriesPageModel(
                title: page.title,
                description: page.description,
                button: button,
                links: links,
                backgroundImage: .urlImage(page.image)
            )
        }

        let initialIndex = isClosable ? storiesStore.nextPageIndex(for: story.id, totalPages: story.pages.count) : 0

        let storiesViewController = TKStoriesFactory.storiesViewController(models: models)
        storiesViewController.setInitialPage(initialIndex)
        storiesViewController.isModalInPresentation = !isClosable
        if isClosable {
            storiesViewController.didComplete = { [weak storiesViewController] in
                dismissReason = .completed
                storiesViewController?.dismiss(animated: true)
            }
        }
        storiesViewController.didOpen = { [weak self, analyticsProvider] in
            analyticsProvider.log(eventKey: .storyOpen, args: ["story_id": story.id, "from": fromAnalyticsProperty])
            analyticsProvider.log(eventKey: .storyPageView, args: ["story_id": story.id, "page_number": initialIndex + 1])
            self?.storiesStore.setStoryWatchedPageIndex(story.id, pageIndex: initialIndex)
            if initialIndex >= story.pages.count - 1 {
                self?.storiesStore.setStoryWatched(story.id)
            }
        }
        storiesViewController.didOpenPage = { [weak self, analyticsProvider] pageNumber in
            analyticsProvider.log(eventKey: .storyPageView, args: ["story_id": story.id, "page_number": pageNumber + 1])
            self?.storiesStore.setStoryWatchedPageIndex(story.id, pageIndex: pageNumber)
            if pageNumber >= story.pages.count - 1 {
                self?.storiesStore.setStoryWatched(story.id)
            }
        }

        self.storiesViewController = storiesViewController

        storiesViewController.storiesPresentationController?.didDismiss = { [weak self] in
            self?.window = nil
            onDismiss?(dismissReason)
        }

        window.makeKeyAndVisible()
        window.rootViewController?.present(
            storiesViewController,
            animated: true,
            completion: { [weak self] in
                self?.storiesService.markStoryShown(storyID: story.id)
            }
        )
        return true
    }

    @MainActor
    public func dismissCurrentStory() {
        storiesViewController?.dismiss(animated: true)
    }

    private func createWindow(windowScene: UIWindowScene) -> UIWindow {
        let window = TKWindow(windowScene: windowScene)
        window.windowLevel = .statusBar + 1
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController

        return window
    }
}
