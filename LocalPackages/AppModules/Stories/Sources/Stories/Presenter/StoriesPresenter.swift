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
    private var presentedMode = Mode.regular

    /// Story windows of every presenter, so a caller can tell that any story is on screen.
    /// A story counts from its presentation until its dismissal ends, however long its window lives.
    private static let windows = NSHashTable<UIWindow>.weakObjects()

    public static var isAnyStoryOnScreen: Bool {
        windows.allObjects.contains { $0.rootViewController?.presentedViewController != nil }
    }

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

    public enum Mode {
        case regular
        case required
        case withoutLastPageButton
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
        mode: Mode = .regular,
        ignoresStoriesFlag: Bool = false,
        closeAlert: StoriesCloseAlertModel? = nil,
        deeplinkAction: @escaping (String) -> Void,
        urlAction: @escaping (URL) -> Void,
        onDismiss: ((DismissReason) -> Void)? = nil
    ) -> Bool {
        guard !story.pages.isEmpty else { return false }
        guard window == nil || presentedMode != .required else { return false }
        guard let wallet = try? self.walletsStore.activeWallet else { return false }
        guard ignoresStoriesFlag || !configuration.flag(\.storiesDisabled, network: wallet.network) else { return false }
        guard let windowScene = fromViewController.windowScene else { return false }
        let window = createWindow(windowScene: windowScene)
        self.window = window
        Self.windows.add(window)

        let backgroundURLs = story.pages.compactMap { $0.image }
        ImagePrefetcherService().prefetch(urls: backgroundURLs)

        // Recorded at tap time: `deeplinkAction`/`urlAction` only run in the dismissal
        // completion, which UIKit invokes after the presentation controller's own callback.
        var dismissReason = DismissReason.closed

        let lastPageIndex = story.pages.count - 1
        let models: [StoriesPageModel] = story.pages.enumerated().map { [weak self] index, page in
            let isLastPage = index == lastPageIndex
            let showsButton = switch mode {
            case .regular: true
            case .required: isLastPage
            case .withoutLastPageButton: !isLastPage
            }
            var button: StoriesPageModel.Button?
            if let pageButton = page.button, showsButton {
                button = StoriesPageModel.Button(
                    title: pageButton.title,
                    action: { [weak self] in
                        dismissReason = isLastPage ? .lastPageButton : .action
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
                            guard mode != .required else { return }
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

        let initialIndex = mode == .required
            ? storiesStore.resumePageIndex(for: story.id, totalPages: story.pages.count)
            : storiesStore.nextPageIndex(for: story.id, totalPages: story.pages.count)

        let storiesViewController = TKStoriesFactory.storiesViewController(models: models)
        storiesViewController.setInitialPage(initialIndex)
        if mode != .required {
            storiesViewController.didComplete = { [weak storiesViewController] in
                dismissReason = .completed
                storiesViewController?.dismiss(animated: true)
            }
        }
        if let closeAlert {
            storiesViewController.didTapClose = { [weak storiesViewController, analyticsProvider] in
                var isClosing = false
                let pageNumber = (storiesViewController?.activePageIndex ?? 0) + 1
                let close = { (reason: DismissReason, outcome: String) in
                    guard !isClosing else { return }
                    isClosing = true
                    dismissReason = reason
                    analyticsProvider.log(
                        eventKey: .storyCloseAlert,
                        args: ["story_id": story.id, "page_number": pageNumber, "outcome": outcome]
                    )
                    storiesViewController?.presentedViewController?.dismiss(animated: true) {
                        storiesViewController?.dismiss(animated: true)
                    }
                }
                storiesViewController?.present(
                    TKStoriesFactory.closeAlertViewController(
                        model: closeAlert,
                        onSkip: { close(.closed, "skip") },
                        onContinue: { close(.lastPageButton, "continue") }
                    ),
                    animated: true
                )
            }
        }
        storiesViewController.didOpen = { [analyticsProvider] in
            analyticsProvider.log(eventKey: .storyOpen, args: ["story_id": story.id, "from": fromAnalyticsProperty])
        }
        storiesViewController.didOpenPage = { [weak self, analyticsProvider] pageNumber in
            analyticsProvider.log(eventKey: .storyPageView, args: ["story_id": story.id, "page_number": pageNumber + 1])
            self?.storiesStore.setStoryWatchedPageIndex(story.id, pageIndex: pageNumber)
            if pageNumber >= story.pages.count - 1 {
                self?.storiesStore.setStoryWatched(story.id)
            }
        }

        self.storiesViewController = storiesViewController
        presentedMode = mode

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
