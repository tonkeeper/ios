import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class CollectiblesViewController: ContentListEmptyViewController {

  private let viewModel: CollectiblesViewModel
  
  init(viewModel: CollectiblesViewModel) {
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
}

private extension CollectiblesViewController {
  func setup() {
    customView.navigationBarView.title = TKLocales.History.title
    setupBindings()
  }
  
  func setupBindings() {
    viewModel.didUpdateState = { [weak self] state, animated in
      self?.setState(state, animated: animated)
    }
    
    viewModel.didUpdateEmptyModel = { [weak self] model in
      self?.emptyViewController.configure(model: model)
    }
    
    viewModel.didUpdateIsConnecting = { [weak self] isConnecting in
      self?.customView.navigationBarView.isConnecting = isConnecting
    }
  }
}
