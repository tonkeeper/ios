import UIKit
import TKUIKit
import TKCore

enum LinkButtonKind: CaseIterable {
  case tonstakers
  case twitter
  case community
  case tonviewer
}

final class StakingOptionDetailsViewController: GenericViewViewController<StakingOptionDetailsView> {
  private let viewModel: StakingOptionDetailsViewModel
  
  init(viewModel: StakingOptionDetailsViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    
    viewModel.viewDidLoad()
  }
}

// MARK: - Private methods
private extension StakingOptionDetailsViewController {
  func setup() {
    navigationItem.setupBackButton { [weak self] in
      self?.navigationController?.popViewController(animated: true)
    }
  }
  
  func setupBindings() {
    viewModel.didUpdateTitle = { [weak self] title in
      self?.title = title
    }
    
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
  }
}
