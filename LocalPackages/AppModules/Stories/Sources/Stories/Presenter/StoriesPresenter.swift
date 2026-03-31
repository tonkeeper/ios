import KeeperCore
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

    init(
        storiesService: StoriesService,
        storiesStore: StoriesStore,
        walletsStore: WalletsStore,
        analyticsProvider: AnalyticsProvider,
        configuration: Configuration
    ) {
        self.storiesService = storiesService
        self.storiesStore = storiesStore
        self.walletsStore = walletsStore
        self.analyticsProvider = analyticsProvider
        self.configuration = configuration
    }

    @MainActor
    public func presentStory(
        story: Story,
        fromViewController: UIViewController,
        fromAnalyticsProperty: String,
        deeplinkAction: @escaping (String) -> Void,
        urlAction: @escaping (URL) -> Void
    ) {
        guard !story.pages.isEmpty else { return }
        guard let wallet = try? self.walletsStore.activeWallet else { return }
        guard !configuration.flag(\.storiesDisabled, network: wallet.network) else { return }
        guard let windowScene = fromViewController.windowScene else { return }
        let window = createWindow(windowScene: windowScene)
        self.window = window

        let backgroundURLs = story.pages.compactMap { $0.image }
        ImagePrefetcherService().prefetch(urls: backgroundURLs)

        let models: [StoriesPageModel] = story.pages.enumerated().map { [weak self] index, page in
            var button: StoriesPageModel.Button?
            if let pageButton = page.button {
                button = StoriesPageModel.Button(
                    title: pageButton.title,
                    action: { [weak self] in
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

            return StoriesPageModel(
                title: page.title,
                description: page.description,
                button: button,
                backgroundImage: .urlImage(page.image)
            )
        }

        let initialIndex = storiesStore.nextPageIndex(for: story.id, totalPages: story.pages.count)

        let storiesViewController = TKStoriesFactory.storiesViewController(models: models)
        storiesViewController.setInitialPage(initialIndex)
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
        }

        window.makeKeyAndVisible()
        window.rootViewController?.present(
            storiesViewController,
            animated: true,
            completion: { [weak self] in
                self?.storiesService.markStoryShown(storyID: story.id)
            }
        )
    }

    private func createWindow(windowScene: UIWindowScene) -> UIWindow {
        let window = TKWindow(windowScene: windowScene)
        window.windowLevel = .statusBar + 1
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController

        return window
    }
}
