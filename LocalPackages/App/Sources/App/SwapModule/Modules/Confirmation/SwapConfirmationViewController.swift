import UIKit
import TKUIKit

final class SwapConfirmationViewController: GenericViewViewController<SwapConfirmationView> {
  
  private let viewModel: SwapConfirmationViewModel
  
  init(viewModel: SwapConfirmationViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self.viewModel.viewDidLoad()
    }
  }
}
