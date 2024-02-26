import UIKit
import TKUIKit

final class WalletsListViewController: GenericViewViewController<WalletsListView>, TKBottomSheetScrollContentViewController {
  private let viewModel: WalletsListViewModel

  lazy var collectionController = WalletsListCollectionController(
    collectionView: customView.collectionView,
    footerViewProvider: { [customView] in
      customView.footerView
    })
  
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewModel.viewWillAppear()
  }
  
  // MARK: - TKPullCardScrollableContent
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  var didUpdateHeight: (() -> Void)?
  var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    scrollView.contentSize.height
  }
}

private extension WalletsListViewController {
  func setupBindings() {
    self.customView.collectionView.allowsSelectionDuringEditing = true
    viewModel.didUpdateHeaderItem = { [weak self] in
      self?.didUpdatePullCardHeaderItem?($0)
    }
    
    viewModel.didUpdateIsEditing = { [weak collectionController] isEditing in
      UIView.animate(withDuration: 0.2) {
        collectionController?.isEditing = isEditing
      }
    }
    
    viewModel.didUpdateItems = { [weak self, weak collectionController] items in
      collectionController?.setWallets(items)
      self?.didUpdateHeight?()
    }
    
    viewModel.didUpdateFooterModel = { [weak customView] in
      customView?.footerView.configure(model: $0)
    }
    
    viewModel.didUpdateSelectedItem = { [weak customView] index, animated, isScrollToItem in
      guard let index = index else {
        return
      }
      let indexPath = IndexPath(item: index, section: 0)
      let scrollPosition: UICollectionView.ScrollPosition = isScrollToItem ? [.bottom] : []
      DispatchQueue.main.async {
        customView?.collectionView.selectItem(at: indexPath, animated: animated, scrollPosition: scrollPosition)
      }
    }
  }
  
  func setupCollectionController() {
    collectionController.didSelect = { [weak viewModel] _, index in
      viewModel?.didSelectWallet(at: index)
    }
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
