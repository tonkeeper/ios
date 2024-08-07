import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class HistoryViewController: GenericViewViewController<HistoryView> {
  enum State {
    case empty
    case list
  }
  
  private var state: State = .empty {
    didSet {
      switch state {
      case .empty:
        customView.showEmpty()
        customView.navigationBarView.isHidden = true
      case .list:
        customView.showList()
        customView.navigationBarView.isHidden = false
      }
    }
  }
  
  private let viewModel: HistoryViewModel
  
  private let emptyViewController = TKEmptyViewController()
  private var listViewController: HistoryListViewController?
  
  init(viewModel: HistoryViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationController?.setNavigationBarHidden(true, animated: false)
    
    setup()
    
    viewModel.viewDidLoad()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    listViewController?.additionalSafeAreaInsets.top = customView.navigationBarView.additionalInset
  }
  
  func setListViewController(_ viewController: HistoryListViewController) {
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
      self.customView.navigationBarView.scrollView = self.listViewController?.customView.collectionView
    }
  }
}

private extension HistoryViewController {
  func setup() {
    customView.navigationBarView.title = TKLocales.History.title
    setupEmptyView()
    setupBindings()
  }
  
  func setupEmptyView() {
    addChild(emptyViewController)
    customView.embedEmptyView(emptyViewController.view)
    emptyViewController.didMove(toParent: self)
  }

  func setupBindings() {
    viewModel.didUpdateState = { [weak self] state in
      self?.state = state
    }
    
    viewModel.didUpdateEmptyModel = { [weak self] model in
      self?.emptyViewController.configure(model: model)
    }
    
    viewModel.didUpdateIsConnecting = { [weak self] isConnecting in
      self?.customView.navigationBarView.isConnecting = isConnecting
    }
  }
}
