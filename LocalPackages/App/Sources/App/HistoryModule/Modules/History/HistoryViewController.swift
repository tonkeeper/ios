import UIKit
import TKUIKit

final class HistoryViewController: GenericViewViewController<HistoryView> {
  private let viewModel: HistoryViewModel
  
  private var emptyViewController: UIViewController?
  private var listViewController: UIViewController?
  
  init(viewModel: HistoryViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
    
    customView.showList()
  }
}

// MARK: - Private

private extension HistoryViewController {
  func setupBindings() {
    viewModel.didUpdateEmptyViewController = { [weak self] viewController in
      self?.setupEmptyViewController(viewController: viewController)
    }
    
    viewModel.didUpdateListViewController = { [weak self] viewController in
      self?.setupListViewController(viewController: viewController)
    }
  }
  
  func setupEmptyViewController(viewController: UIViewController) {
    self.emptyViewController?.removeFromParent()
    self.emptyViewController = viewController
    addChild(viewController)
    customView.addEmptyContentView(view: viewController.view)
    viewController.didMove(toParent: self)
  }
  
  func setupListViewController(viewController: UIViewController) {
    self.listViewController?.removeFromParent()
    self.listViewController = viewController
    addChild(viewController)
    customView.addListContentView(view: viewController.view)
    viewController.didMove(toParent: self)
  }
}

