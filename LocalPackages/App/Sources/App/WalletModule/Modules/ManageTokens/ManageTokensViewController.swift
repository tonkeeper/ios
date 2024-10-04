import UIKit
import TKUIKit
import TKLocalize

final class ManageTokensViewController: GenericViewViewController<ManageTokensView>, TKBottomSheetScrollContentViewController {
  typealias Section = ManageTokensSection
  typealias Item = ManageTokensListItem
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  
  private let viewModel: ManageTokensViewModel

  private lazy var reorderGesture: UILongPressGestureRecognizer = {
    let gesture = UILongPressGestureRecognizer(
      target: self,
      action: #selector(handleReorderGesture(gesture:))
    )
    gesture.isEnabled = true
    return gesture
  }()
  
  init(viewModel: ManageTokensViewModel) {
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
  
  private lazy var dataSource: DataSource = {
    let listItemCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    
    let dataSource = DataSource(
      collectionView: customView.collectionView) {
        [weak self] collectionView, indexPath, itemIdentifier in
        guard let self else { return nil }
        guard let cellConfiguration = self.viewModel.getItemCellConfiguration(item: itemIdentifier) else { return nil }
        let cell = collectionView.dequeueConfiguredReusableCell(
          using: listItemCellRegistration,
          for: indexPath,
          item: cellConfiguration)
        cell.defaultAccessoryViews = itemIdentifier.accessories.map { $0.view }
        return cell
      }
    
    let headerViewRegistration = ManageTokensListSectionHeaderViewRegistration.registration()
    dataSource.supplementaryViewProvider = {
      [weak self] collectionView, elementKind, indexPath in
      guard let snapshot = self?.dataSource.snapshot() else { return nil }
      let section = snapshot.sectionIdentifiers[indexPath.section]
      
      switch elementKind {
      case ManageTokensListSectionHeaderView.elementKind:
        let configuration = section.headerConfiguration
        let view = collectionView.dequeueConfiguredReusableSupplementary(
          using: headerViewRegistration,
          for: indexPath
        )
        view.configuration = configuration
        return view
      default: return nil
      }
    }
    
    dataSource.reorderingHandlers.canReorderItem = { [weak self] itemIdentifier in
      itemIdentifier.canReorder
    }
    
    dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
      self?.didReorder(transaction: transaction)
    }
    return dataSource
  }()
  
  private var layout: UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] sectionIndex, _ in
      guard let snapshot = self?.dataSource.snapshot() else { return nil}
      
      let sectionLayout: NSCollectionLayoutSection = .listItemsSection
      sectionLayout.contentInsets.bottom = 16
      
      if !snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[sectionIndex]).isEmpty {
        let headerSize = NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(100)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
          layoutSize: headerSize,
          elementKind: ManageTokensListSectionHeaderView.elementKind,
          alignment: .top
        )
        
        sectionLayout.boundarySupplementaryItems.append(header)
      }
      
      return sectionLayout
    }, configuration: configuration)
    return layout
  }
  
  private func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    customView.collectionView.addGestureRecognizer(reorderGesture)
    setupNavigationBar()
  }
  
  private func setupNavigationBar() {
    customView.navigationBar.rightViews = [
      TKUINavigationBar.createCloseButton(action: { [weak self] in
        self?.dismiss(animated: true)
      })
    ]
  }
}

private extension ManageTokensViewController {
  func setupBindings() {
    viewModel.didUpdateTitleView = { [weak self] model in
      self?.customView.titleView.configure(model: model)
    }
    
    viewModel.didUpdateSnapshot = { [weak self] snapshot, isAnimated in
      guard let self else { return }
      self.dataSource.apply(snapshot, animatingDifferences: isAnimated)
      self.didUpdateHeight?()
    }
  }
  
  @objc
  func handleReorderGesture(gesture: UIGestureRecognizer) {
    let collectionView = customView.collectionView

    switch(gesture.state) {
    case .began:
      guard let selectedIndexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else {
        break
      }
      collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
      viewModel.didStartDragging()
    case .changed:
      var location = gesture.location(in: gesture.view!)
      location.x = collectionView.bounds.width/2
      collectionView.updateInteractiveMovementTargetPosition(location)
    case .ended:
      collectionView.endInteractiveMovement()
      viewModel.didStopDragging()
    default:
      collectionView.cancelInteractiveMovement()
      viewModel.didStopDragging()
    }
  }
  
  func didReorder(transaction: NSDiffableDataSourceTransaction<Section, Item>) {
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
      viewModel.movePinnedItem(from: move.from, to: move.to)
    }
  }
}

extension ManageTokensViewController: UICollectionViewDelegate {
  
  func collectionView(_ collectionView: UICollectionView, 
                      shouldSelectItemAt indexPath: IndexPath) -> Bool {
    false
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
    false
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath,
                      toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
    let snapshot = dataSource.snapshot()
    let proposedSection = snapshot.sectionIdentifiers[proposedIndexPath.section]
    guard proposedSection == .pinned else {
      return originalIndexPath
    }
    return proposedIndexPath
  }
}

private extension String {
  static let sectionHeaderElementKind = "SectionHeaderElementKind"
}
