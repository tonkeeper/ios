import UIKit
import TKUIKit
import TKStories
import TKCore
import KeeperCore

@MainActor
public final class StoriesPresenter {
  
  private var window: UIWindow?
  private var storiesViewController: TKStories.StoriesViewController?
  
  private let storiesService: StoriesService
  private let analyticsProvider: AnalyticsProvider
  
  init(storiesService: StoriesService,
       analyticsProvider: AnalyticsProvider) {
    self.storiesService = storiesService
    self.analyticsProvider = analyticsProvider
  }

  @MainActor
  public func presentStory(story: Story,
                           fromViewController: UIViewController,
                           deeplinkAction: @escaping (String) -> Void,
                           urlAction: @escaping (URL) -> Void) {
    guard let windowScene = fromViewController.view.window?.windowScene ?? UIApplication.keyWindowScene else { return }
    let window = createWindow(windowScene: windowScene)
    self.window = window
    
    let models: [StoriesPageModel] = story.pages.map { [weak self] page in
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
            self?.analyticsProvider.logEvent(
              eventKey: .storyClick,
              args: ["story_id": story.id,
                     "button": pageButton.title]
            )
          }
        )
      }
      
      return StoriesPageModel(title: page.title,
                              description: page.description,
                              button: button,
                              backgroundImage: .urlImage(page.image))
    }
    
    let storiesViewController = TKStoriesFactory.storiesViewController(models: models)
    storiesViewController.didOpen = { [analyticsProvider] in
      analyticsProvider.logEvent(eventKey: .storyOpen, args: ["story_id": story.id])
      analyticsProvider.logEvent(eventKey: .storyPageView, args: ["story_id": story.id, "page_number": 1])
    }
    storiesViewController.didOpenPage = { [analyticsProvider] pageNumber in
      analyticsProvider.logEvent(eventKey: .storyPageView, args: ["story_id": story.id, "page_number": pageNumber + 1])
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
