import UIKit
import TKUIKit

final class HistoryEmptyViewController: GenericViewViewController<HistoryEmptyView> {
  private let viewModel: HistoryEmptyViewModel
  
  init(viewModel: HistoryEmptyViewModel) {
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

private extension HistoryEmptyViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [customView] in
      customView.configure(model: $0)
    }
  }
}
