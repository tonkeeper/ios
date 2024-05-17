import UIKit
import TKUIKit
import TKCore

final class StakingOptionsViewController: GenericViewViewController<StakingOptionsView> {
  private let viewModel: StakingOptionsViewModel
  
  var collectionController: StakingOptionCollectionController?
  
  init(viewModel: StakingOptionsViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionController = StakingOptionCollectionController(collectionView: customView.collectionView)
    
    setup()
    setupBindings()
    setupViewEvents()
    viewModel.viewDidLoad()
  }
}

// MARK: - Private methods

private extension StakingOptionsViewController {
  func setup() {
    title = .moduleTitle
    navigationItem.setupBackButton { [weak self] in
      self?.navigationController?.popViewController(animated: true)
    }
  }
  
  func setupBindings() {
    viewModel.didUpdateSections = { [weak collectionController] sections in
      collectionController?.setOptionSections(sections)
    }
  }
  
  func setupViewEvents() {
    collectionController?.didSelect = { [weak viewModel] section, index in
      viewModel?.selectItem(section: section, index: index)
    }
  }
}

private extension String {
  static let moduleTitle: Self = "Options"
}
