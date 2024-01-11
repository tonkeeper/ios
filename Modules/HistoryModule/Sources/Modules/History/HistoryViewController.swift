import UIKit
import TKUIKit

final class HistoryViewController: GenericViewViewController<HistoryView> {
  private let viewModel: HistoryViewModel
  
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
  }
}

private extension HistoryViewController {
  func setupBindings() {}
}