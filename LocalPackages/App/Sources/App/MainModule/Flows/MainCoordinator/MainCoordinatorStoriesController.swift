import UIKit
import Stories

final class MainCoordinatorStoriesController {
  
  var fromViewControllerProvider: (() -> UIViewController?)?
  var deeplinkAction: ((String) -> Void)?
  var urlAction: ((URL) -> Void)?
  
  private let storiesPresenter: Stories.StoriesPresenter
  private let storiesController: Stories.StoriesController
  
  init(storiesPresenter: Stories.StoriesPresenter, 
       storiesController: Stories.StoriesController) {
    self.storiesPresenter = storiesPresenter
    self.storiesController = storiesController
  }
  
  func start() {
    guard let fromViewController = fromViewControllerProvider?() else { return }
    Task { @MainActor in
      let result = await storiesController.loadStories()
      switch result {
      case .success(let story):
        storiesPresenter.presentStory(
          story: story,
          fromViewController: fromViewController,
          fromAnalyticsProperty: "wallet",
          deeplinkAction: { [weak self] in
            self?.deeplinkAction?($0)
          }, urlAction: { [weak self] in
            self?.urlAction?($0)
          })
      case .failure:
        break
      }
    }
  }
  
  @MainActor
  func handleDeeplinkStory(storyId: String) async throws {
    guard let fromViewController = fromViewControllerProvider?() else { return }
    let result = await storiesController.loadStory(storyId: storyId, ignoreShowed: true)
    switch result {
    case .success(let story):
      storiesPresenter.presentStory(
        story: story,
        fromViewController: fromViewController,
        fromAnalyticsProperty: "deep-link",
        deeplinkAction: { [weak self] in
          self?.deeplinkAction?($0)
        }, urlAction: { [weak self] in
          self?.urlAction?($0)
        })
    case .failure(let error):
      throw error
    }
  }
}
