import UIKit
import TKUIKit
import TKScreenKit
import TKStories
import KeeperCore

final class StoriesPresenter {

  private var window: UIWindow?
  private var storiesViewController: TKStories.StoriesViewController?
  
  func presentStory(story: Story,
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
          action: {
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
          }
        )
      }
      
      return StoriesPageModel(title: page.title,
                              description: page.description,
                              button: button,
                              backgroundImage: .urlImage(page.image))
    }
    
    let storiesViewController = TKStories.Stories.storiesViewController(models: models)
    self.storiesViewController = storiesViewController
    
    storiesViewController.storiesPresentationController?.didDismiss = { [weak self] in
      self?.window = nil
    }
   
    window.makeKeyAndVisible()
    window.rootViewController?.present(storiesViewController, animated: true)
  }
  
  private func createWindow(windowScene: UIWindowScene) -> UIWindow {
    let window = TKWindow(windowScene: windowScene)
    window.windowLevel = .statusBar + 1
    let rootViewController = UIViewController()
    window.rootViewController = rootViewController
    
    return window
  }
}
