import UIKit
import TKUIKit
import TKCoordinator

final class HistoryV2ViewController: GenericViewViewController<HistoryV2View> {
  enum State {
    case empty
    case list
  }
  
  private var state: State = .empty {
    didSet {
      switch state {
      case .empty:
        customView.showEmpty()
      case .list:
        customView.showList()
      }
    }
  }
  
  private let viewModel: HistoryV2ViewModel
  
  private let emptyViewController = TKEmptyViewController()
  private var listViewController: UIViewController?
  
  init(viewModel: HistoryV2ViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    
    viewModel.viewDidLoad()
  }
  
  func setListViewController(_ viewController: UIViewController) {
    if let listViewController {
      listViewController.willMove(toParent: self)
      listViewController.view.removeFromSuperview()
      listViewController.removeFromParent()
    }
    addChild(viewController)
    customView.embedListView(viewController.view)
    viewController.didMove(toParent: self)
    listViewController = viewController
  }
}

private extension HistoryV2ViewController {
  func setup() {
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
  }
}
