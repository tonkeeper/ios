import UIKit
import TKUIKit

final class CollectiblesViewController: GenericViewViewController<CollectiblesView> {
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
    
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension CollectiblesViewController {
  func setupBindings() {}
}
