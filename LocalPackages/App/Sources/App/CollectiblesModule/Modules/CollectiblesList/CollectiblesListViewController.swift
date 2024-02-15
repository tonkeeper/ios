import UIKit
import TKUIKit

final class CollectiblesListViewController: GenericViewViewController<CollectiblesListView> {
  
  private var collectionController: CollectiblesListCollectionController!
  
  private let viewModel: CollectiblesListViewModel
  
  init(viewModel: CollectiblesListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionController = CollectiblesListCollectionController(
      collectionView: customView.collectionView
    )
    
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension CollectiblesListViewController {
  func setupBindings() {
    viewModel.didUpdateSections = { [weak collectionController] sections in
      collectionController?.setSections(sections)
    }
    
    collectionController.loadNextPage = { [weak viewModel] in
      viewModel?.loadNext()
    }
  }
}
