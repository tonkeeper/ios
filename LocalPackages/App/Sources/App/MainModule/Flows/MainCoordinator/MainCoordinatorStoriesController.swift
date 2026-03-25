import Stories
import UIKit

final class MainCoordinatorStoriesController {
    var fromViewControllerProvider: (() -> UIViewController?)?
    var deeplinkAction: ((String) -> Void)?
    var urlAction: ((URL) -> Void)?

    private let storiesPresenter: Stories.StoriesPresenter
    private let storiesController: Stories.StoriesController

    init(
        storiesPresenter: Stories.StoriesPresenter,
        storiesController: Stories.StoriesController
    ) {
        self.storiesPresenter = storiesPresenter
        self.storiesController = storiesController
    }

    @MainActor
    func handleDeeplinkStory(storyId: String) async throws {
        guard let fromViewController = fromViewControllerProvider?() else { return }
        let result = await storiesController.loadStory(storyId: storyId, ignoreShowed: true)
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
                }
            )
        case let .failure(error):
            throw error
        }
    }

    @MainActor func presentStory(
        story: Stories.Story,
        fromViewController: UIViewController,
        fromAnalyticsProperty: String,
        shouldDismissCurrentOnAction: Bool = false
    ) {
        storiesPresenter.presentStory(
            story: story,
            fromViewController: fromViewController,
            fromAnalyticsProperty: fromAnalyticsProperty,
            deeplinkAction: { [weak self] in
                if shouldDismissCurrentOnAction {
                    fromViewController.dismiss(animated: true)
                }
                self?.deeplinkAction?($0)
            }, urlAction: { [weak self] in
                if shouldDismissCurrentOnAction {
                    fromViewController.dismiss(animated: true)
                }
                self?.urlAction?($0)
            }
        )
    }
}
