import UIKit
import TKUIKit

final class SendConfirmationViewController: GenericViewViewController<SendConfirmationView> {
  private let viewModel: SendConfirmationViewModel
  
  init(viewModel: SendConfirmationViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .Background.page
    
    setup()
    setupBindings()
    setupViewEventsBinding()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    viewModel.viewWillDisappear()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.viewDidAppear()
  }
}

private extension SendConfirmationViewController {
  func setup() {
  
  }
  
  func setupBindings() {
   
  }
  
  func setupViewEventsBinding() {

  }
}
