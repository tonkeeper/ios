import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

protocol ContentListEmptyViewControllerListViewController: UIViewController {
  var scrollView: UIScrollView { get }
}

class ContentListEmptyViewController: GenericViewViewController<ContentListEmptyView> {
  enum State {
    case empty
    case list
  }
  
  private var state: State = .empty
  
  let emptyViewController = TKEmptyViewController()
  private(set) var listViewController: ContentListEmptyViewControllerListViewController?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationController?.setNavigationBarHidden(true, animated: false)
    
    setup()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    listViewController?.additionalSafeAreaInsets.top = customView.navigationBarView.additionalInset
  }
  
  func setState(_ state: ContentListEmptyViewController.State, animated: Bool) {
    let navigationBarIsHidden: Bool
    let navigationBarAlpha: CGFloat
    switch state {
    case .empty:
      customView.showEmpty()
      navigationBarIsHidden = true
      navigationBarAlpha = 0
    case .list:
      customView.showList()
      navigationBarIsHidden = false
      navigationBarAlpha = 1
    }
    UIView.animate(withDuration: animated ? 0.2 : 0) {
      self.customView.navigationBarView.alpha = navigationBarAlpha
    } completion: { _ in
      self.customView.navigationBarView.isHidden = navigationBarIsHidden
    }
  }
  
  func setListViewController(_ viewController: ContentListEmptyViewControllerListViewController) {
    if let listViewController {
      listViewController.willMove(toParent: self)
      listViewController.view.removeFromSuperview()
      listViewController.removeFromParent()
    }
    addChild(viewController)
    customView.embedListView(viewController.view)
    viewController.didMove(toParent: self)
    listViewController = viewController
    DispatchQueue.main.async {
      self.customView.navigationBarView.scrollView = self.listViewController?.scrollView
    }
  }
}

private extension ContentListEmptyViewController {
  func setup() {
    setupEmptyView()
  }
  
  func setupEmptyView() {
    addChild(emptyViewController)
    customView.embedEmptyView(emptyViewController.view)
    emptyViewController.didMove(toParent: self)
  }
}
