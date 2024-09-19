import UIKit
import TKUIKit

final class WalletsListViewController: GenericViewViewController<WalletsListView>, TKBottomSheetScrollContentViewController {
  typealias Section = WalletsListSection
  typealias Item = WalletsListItem
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  
  private let viewModel: WalletsListViewModel
  
  private lazy var reorderGesture: UILongPressGestureRecognizer = {
    let gesture = UILongPressGestureRecognizer(
      target: self,
      action: #selector(handleReorderGesture(gesture:))
    )
    gesture.isEnabled = false
    return gesture
  }()
  
  init(viewModel: WalletsListViewModel) {
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
  
  private func setup() {
    customView.collectionView.collectionViewLayout = layout
    customView.collectionView.delegate = self
    customView.collectionView.addGestureRecognizer(reorderGesture)
  }
  
  private func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false, completion: { [weak self] in
        self?.didUpdateHeight?()
        self?.selectWallet()
      })
    }
    
    viewModel.didUpdateWaletCellConfiguration = { [weak self] item, configuration in
      guard let indexPath = self?.dataSource.indexPath(for: item),
            let cell = self?.customView.collectionView.cellForItem(at: indexPath) as? TKListItemCell else {
        return
      }
      cell.configuration = configuration
    }
    
    viewModel.didUpdateHeaderItem = { [weak self] headerItem in
      self?.didUpdatePullCardHeaderItem?(headerItem)
    }
    
    viewModel.didUpdateIsEditing = { [weak self] isEditing in
      self?.reorderGesture.isEnabled = isEditing
      UIView.animate(withDuration: 0.2) {
        self?.customView.collectionView.isEditing = isEditing
      }
      if !isEditing {
        self?.selectWallet()
      }
    }
  }
  
  private lazy var dataSource: DataSource = {
    let listItemCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    
    let dataSource = DataSource(
      collectionView: customView.collectionView) {
        [weak self] collectionView, indexPath, itemIdentifier in
        guard let self else { return nil }
        guard let cellConfiguration = self.viewModel.getWalletCellConfiguration(
          identifier: itemIdentifier.identifier) else { return nil }
        let cell = collectionView.dequeueConfiguredReusableCell(
          using: listItemCellRegistration,
          for: indexPath,
          item: cellConfiguration)
        cell.selectionAccessoryViews = itemIdentifier.selectAccessories.map { $0.view }
        cell.editingAccessoryViews = itemIdentifier.editingAccessories.map { $0.view }
        return cell
      }
    
    let listButtonFooterRegistration = TKListCollectionViewButtonFooterViewRegistration.registration()
    dataSource.supplementaryViewProvider = { [weak self] collectionView, elementKind, indexPath in
      guard let snapshot = self?.dataSource.snapshot() else { return nil }
      let snapshotSection = snapshot.sectionIdentifiers[indexPath.section]
      switch elementKind {
      case TKListCollectionViewButtonFooterView.elementKind:
        switch snapshotSection {
        case .wallets(let footerConfiguration):
          let view = collectionView.dequeueConfiguredReusableSupplementary(
            using: listButtonFooterRegistration,
            for: indexPath
          )
          view.configuration = footerConfiguration
          return view
        default: return nil
        }
      default:
        return nil
      }
    }
    
    dataSource.reorderingHandlers.canReorderItem = { [weak self] itemIdentifier in
      true
    }
    
    dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
      self?.didReorder(transaction: transaction)
    }
    return dataSource
  }()
  
  private var layout: UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [weak dataSource] sectionIndex, _ in
        guard let dataSource else { return nil }
        let snapshotSection = dataSource.snapshot().sectionIdentifiers[sectionIndex]
        
        switch snapshotSection {
        case .wallets:
          let sectionLayout: NSCollectionLayoutSection = .listItemsSection
          let footerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(100)
          )
          let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerSize,
            elementKind: TKListCollectionViewButtonFooterView.elementKind,
            alignment: .bottom
          )
          sectionLayout.boundarySupplementaryItems.append(footer)
          return sectionLayout
        }
      },
      configuration: configuration
    )
    return layout
  }
  
  @objc
  private func handleReorderGesture(gesture: UIGestureRecognizer) {
    let collectionView = customView.collectionView
    
    switch(gesture.state) {
    case .began:
      guard let selectedIndexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else {
        break
      }
      collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
    case .changed:
      var location = gesture.location(in: gesture.view!)
      location.x = collectionView.bounds.width/2
      collectionView.updateInteractiveMovementTargetPosition(location)
    case .ended:
      collectionView.endInteractiveMovement()
    default:
      collectionView.cancelInteractiveMovement()
    }
  }
  
  private func didReorder(transaction: NSDiffableDataSourceTransaction<WalletsListSection, WalletsListItem>) {
    var deletes = [Int]()
    var inserts = [Int]()
    var moves = [(from: Int, to: Int)]()
    
    for update in transaction.difference.inferringMoves() {
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
    for move in moves {
      viewModel.moveWallet(fromIndex: move.from, toIndex: move.to)
    }
  }
  
  private func selectWallet() {
    guard let selectedWalletIndex = viewModel.selectedWalletIndex else {
      return
    }
    customView.collectionView.selectItem(
      at: IndexPath(
        item: selectedWalletIndex,
        section: 0
      ),
      animated: false,
      scrollPosition: .centeredVertically
    )
  }
}

extension WalletsListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    item.onSelection?()
  }
}
