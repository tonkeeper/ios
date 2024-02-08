import UIKit
import TKUIKit

final class HistoryListViewController: GenericViewViewController<HistoryListView> {
  
  private var collectionController: HistoryListCollectionController!
  
  private let viewModel: HistoryListViewModel
  
  init(viewModel: HistoryListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionController = HistoryListCollectionController(collectionView: customView.collectionView)
    
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension HistoryListViewController {
  func setupBindings() {
    viewModel.didUpdateHistory = { [weak collectionController] sections in
      collectionController?.setSections(sections)
    }
    
    collectionController.loadNextPage = { [weak viewModel] in 
      viewModel?.loadNext()
    }
  }
}
