import UIKit
import TKUIKit

final class WalletsListViewController: GenericViewViewController<WalletsListView>, TKBottomSheetScrollContentViewController {
  enum Section: Hashable {
    case wallets
  }
  
  private let viewModel: WalletsListViewModel
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: size,
      elementKind: .footerElementKind,
      alignment: .bottom
    )
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.boundarySupplementaryItems = [footer]
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .wallets:
          return .walletsSection
        }
      },
      configuration: configuration
    )
    return layout
  }()

  private lazy var dataSource = createDataSource()
  private lazy var listItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in ip.item == 0 }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  }
  
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
}

private extension WalletsListViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    customView.collectionView.addGestureRecognizer(reorderGesture)
    customView.collectionView.register(
      TKReusableContainerView.self,
      forSupplementaryViewOfKind: .footerElementKind,
      withReuseIdentifier: TKReusableContainerView.reuseIdentifier
    )
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.wallets])
    dataSource.apply(snapshot,animatingDifferences: false)
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<Section, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<Section, AnyHashable>(
      collectionView: customView.collectionView) { [weak self, listItemCellConfiguration] collectionView, indexPath, itemIdentifier in
        guard let self else { return nil }
        switch itemIdentifier {
        case let listCellConfiguration as TKUIListItemCell.Configuration:
          let cell = collectionView.dequeueConfiguredReusableCell(
            using: listItemCellConfiguration,
            for: indexPath,
            item: listCellConfiguration)
          
          cell.selectionAccessoryViews = self.createSelectionAccessoryViews()
          cell.editingAccessoryViews = self.createEditingAccessoryViews(indexPath: indexPath)
          return cell
        default: return nil
        }
      }
    
    dataSource.supplementaryViewProvider = { [weak footerView = customView.footerView] collectionView, kind, indexPath -> UICollectionReusableView? in
      switch kind {
      case String.footerElementKind:
        let view = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: TKReusableContainerView.reuseIdentifier,
          for: indexPath
        ) as? TKReusableContainerView
        view?.setContentView(footerView)
        return view
      default: return nil
      }
    }
    
    dataSource.reorderingHandlers.canReorderItem = { [weak collectionView = customView.collectionView] _ in
      collectionView?.isEditing ?? false
    }
    
    dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
      self?.didReorder(transaction: transaction)
    }
    
    return dataSource
  }
  
  func setupBindings() {
    viewModel.didUpdateItems = { [weak self, weak dataSource] items in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .wallets))
      snapshot.appendItems(items, toSection: .wallets)
      if #available(iOS 15.0, *) {
        snapshot.reconfigureItems(items)
      } else {
        snapshot.reloadItems(items)
      }
      dataSource.apply(snapshot, animatingDifferences: false)
      self?.didUpdateHeight?()
    }
    
    viewModel.didUpdateSelected = { [weak self] index in
      if let index {
        let indexPath = IndexPath(item: index, section: 0)
        self?.customView.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
      } else if let indexPathsForSelectedItems = self?.customView.collectionView.indexPathsForSelectedItems {
        indexPathsForSelectedItems.forEach {
          self?.customView.collectionView.deselectItem(at: $0, animated: false)
        }
      }
    }
    
    viewModel.didUpdateHeaderItem = { [weak self] headerItem in
      self?.didUpdatePullCardHeaderItem?(headerItem)
    }
    
    viewModel.didUpdateIsEditing = { [weak self] isEditing in
      self?.reorderGesture.isEnabled = isEditing
      UIView.animate(withDuration: 0.2) {
        self?.customView.collectionView.isEditing = isEditing
      }
    }
    
    viewModel.didUpdateFooterModel = { [weak customView] in
      customView?.footerView.configure(model: $0)
    }
  }
  
  func createSelectionAccessoryViews() -> [UIView] {
    var configuration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    configuration.contentPadding.right = 16
    configuration.iconTintColor = .Accent.blue
    configuration.content.icon = .TKUIKit.Icons.Size28.donemarkOutline
    let button = TKButton(configuration: configuration)
    button.isUserInteractionEnabled = false
    return [button]
  }
  
  func createEditingAccessoryViews(indexPath: IndexPath) -> [UIView] {
    var editConfiguration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    editConfiguration.contentPadding.right = 16
    editConfiguration.iconTintColor = .Icon.tertiary
    editConfiguration.content.icon = .TKUIKit.Icons.Size28.pencilOutline
    editConfiguration.action = { [weak self] in
      self?.viewModel.didTapEdit(index: indexPath.item)
    }
    let editButton = TKButton(configuration: editConfiguration)
    
    var reorderConfiguration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    reorderConfiguration.contentPadding.right = 16
    reorderConfiguration.iconTintColor = .Icon.secondary
    reorderConfiguration.content.icon = .TKUIKit.Icons.Size28.reorder
    let reorderButton = TKButton(configuration: reorderConfiguration)
    reorderButton.isUserInteractionEnabled = false
    
    return [editButton, reorderButton]
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
  
  func didReorder(transaction: NSDiffableDataSourceTransaction<Section, AnyHashable>) {
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
}

extension WalletsListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    switch item {
    case let model as TKUIListItemCell.Configuration:
      model.selectionClosure?()
    default:
      return
    }
  }
}

private extension String {
  static let footerElementKind = "FooterElementKind"
}

private extension NSCollectionLayoutSection {
  static var walletsSection: NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(76)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(76)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 0,
      trailing: 16
    )
    return section
  }
}
