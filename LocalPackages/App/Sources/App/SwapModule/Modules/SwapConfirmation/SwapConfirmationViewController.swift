import UIKit
import TKUIKit

final class SwapConfirmationViewController: ModalViewController<SwapConfirmationView, ModalNavigationBarView> {
  
  // MARK: - Dependencies
  
  private let viewModel: SwapConfirmationViewModel
  
  // MARK: - Init
  
  init(viewModel: SwapConfirmationViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
  
  // MARK: - View Life cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    
    viewModel.viewDidLoad()
  }
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    
    customView.scrollView.contentInset.top = ModalNavigationBarView.defaultHeight
    
    customNavigationBarView.leftItemPadding = 16
    customNavigationBarView.setupLeftBarItem(
      configuration: ModalNavigationBarView.BarItemConfiguration(
        view: customView.titleView,
        contentAlignment: .left
      )
    )
  }
}

// MARK: - Setup

private extension SwapConfirmationViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.backgroundColor = .Background.page
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      customView.configure(model: model)
    }
  }
}
