import UIKit
import TKUIKit

final class CollectiblesEmptyViewController: GenericViewViewController<CollectiblesEmptyView> {
  private let viewModel: CollectiblesEmptyViewModel
  
  init(viewModel: CollectiblesEmptyViewModel) {
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
  }
}

private extension CollectiblesEmptyViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] in
      customView.configure(model: $0)
    }
  }
}
