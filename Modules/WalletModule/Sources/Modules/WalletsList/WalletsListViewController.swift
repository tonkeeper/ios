import UIKit
import TKUIKit

final class WalletsListViewController: GenericViewViewController<WalletsListView>, TKBottomSheetScrollContentViewController {
  private let viewModel: WalletsListViewModel
  
  private lazy var collectionController = TKCollectionController(
    collectionView: customView.collectionView,
    sectionPaddingProvider: { section in
      switch section {
      case .list:
          return NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
      }
    },
    footerViewProvider: { [customView] in customView.footerView }
  )
  
  init(viewModel: WalletsListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupBindings()
    setupCollectionController()
    viewModel.viewDidLoad()
  }
  
  // MARK: - TKPullCardScrollableContent
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  var didUpdateHeight: (() -> Void)?
  var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var headerItem: TKUIKit.TKPullCardHeaderItem?
}

private extension WalletsListViewController {
  func setupBindings() {
    self.customView.collectionView.allowsSelectionDuringEditing = true
    viewModel.didUpdateHeaderItem = { [weak self] in
      self?.didUpdatePullCardHeaderItem?($0)
    }
    
    viewModel.didUpdateIsEditing = { [collectionController] isEditing in
      UIView.animate(withDuration: 0.2) {
        collectionController.isReordering = isEditing
      }
    }
    
    viewModel.didUpdateItems = { [weak self, collectionController] items in
      collectionController.setSections([.list(items: items)], animated: false)
      self?.didUpdateHeight?()
    }
    
    viewModel.didUpdateFooterModel = { [customView] in
      customView.footerView.configure(model: $0)
    }
    
    viewModel.didUpdateSelectedItem = { [customView] index, animated in
      guard let index = index else {
        return
      }
      customView.collectionView.selectItem(at: IndexPath(item: index, section: 0), animated: animated, scrollPosition: [])
    }
  }
  
  func setupCollectionController() {
    collectionController.didReorder = { [weak self] difference in
      var deletes = [Int]()
      var inserts = [Int]()
      var moves = [(from: Int, to: Int)]()
      
      for update in difference.inferringMoves() {
        switch update {
        case let .remove(offset, _, move):
          if let move = move {
            moves.append((offset, move))
          } else {
            deletes.append(offset)
          }
        case let .insert(offset, _, move):
          if move == nil {
            inserts.append(offset)
          }
        }
      }
      
      DispatchQueue.main.async {
        for move in moves {
          self?.viewModel.moveWallet(fromIndex: move.from, toIndex: move.to)
        }
      }
    }
  }
}
