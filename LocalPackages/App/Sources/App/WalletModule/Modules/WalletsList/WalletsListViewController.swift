import UIKit
import TKUIKit

final class WalletsListViewController: GenericViewViewController<WalletsListView>, TKBottomSheetScrollContentViewController {
  private let viewModel: WalletsListViewModel
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .wallets:
          return .walletsSection
        case .addWallet:
          return .addWalletSection
        }
      },
      configuration: configuration
    )
    
    layout.register(WalletsListDecorationBackgroundView.self, forDecorationViewOfKind: WalletsListDecorationBackgroundView.reuseIdentifier)
    
    return layout
  }()

  private lazy var dataSource = createDataSource()

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
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.wallets])
    dataSource.apply(snapshot,animatingDifferences: false)
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<WalletsListSection, WalletsListItem> {
    let walletCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, String> { [weak self] cell, indexPath, identifier in
      guard let self else { return }
      guard let model = self.viewModel.getItemModel(identifier: identifier) as? TKUIListItemCell.Configuration else { return }
      cell.configure(configuration: model)
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { [weak collectionView = self.customView.collectionView] ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
      cell.selectionAccessoryViews = self.createSelectionAccessoryViews()
      cell.editingAccessoryViews = self.createEditingAccessoryViews(item: .wallet(identifier))
    }
    
    let addWalletCellConfiguration = UICollectionView.CellRegistration<TKButtonCell, String> {
      [weak self] cell, indexPath, identifier in
      guard let model = self?.viewModel.getItemModel(identifier: identifier) as? TKButtonCell.Model else { return }
      cell.configure(model: model)
    }
    
    let dataSource = UICollectionViewDiffableDataSource<WalletsListSection, WalletsListItem>(
      collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case .wallet(let identifier):
          let cell = collectionView.dequeueConfiguredReusableCell(
            using: walletCellConfiguration,
            for: indexPath,
            item: identifier)
          return cell
        case .addWalletButton(let identifier):
          let cell = collectionView.dequeueConfiguredReusableCell(
            using: addWalletCellConfiguration,
            for: indexPath,
            item: identifier)
          return cell
        }
      }

    dataSource.reorderingHandlers.canReorderItem = { [weak viewModel] itemIdentifier in
      return viewModel?.canReorderItem(itemIdentifier) ?? false
    }
    
    dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
      self?.didReorder(transaction: transaction)
    }
    
    return dataSource
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot, completion in
      self?.dataSource.apply(snapshot, animatingDifferences: false, completion: { [weak self] in
        self?.didUpdateHeight?()
        completion()
      })
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
    
    viewModel.didUpdateWalletItems = { [weak self] items in
      guard let self else { return }
      items.forEach { identifier, model in
        guard let indexPath = self.dataSource.indexPath(for: .wallet(identifier)),
              let cell = self.customView.collectionView.cellForItem(at: indexPath) as? TKUIListItemCell else { return }
        cell.configure(configuration: model)
      }
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
  
  func createEditingAccessoryViews(item: WalletsListItem) -> [UIView] {
    var editConfiguration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    editConfiguration.contentPadding.right = 16
    editConfiguration.iconTintColor = .Icon.tertiary
    editConfiguration.content.icon = .TKUIKit.Icons.Size28.pencilOutline
    editConfiguration.action = { [weak self] in
      self?.viewModel.didTapEdit(item: item)
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

    let sectionRect = CGRect(x: 0,
                             y: 0,
                             width: view.bounds.width,
                             height: .walletItemCellHeight * CGFloat(collectionView.numberOfItems(inSection: 0)))
    
    switch(gesture.state) {
    case .began:
      guard let selectedIndexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else {
        break
      }
      collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
    case .changed:
      var location = gesture.location(in: gesture.view!)
      location.x = collectionView.bounds.width/2

      if location.y - .draggOffset <= sectionRect.minY {
        location.y = sectionRect.minY + .draggOffset
      }
      if location.y + .draggOffset >= sectionRect.maxY {
        location.y = sectionRect.maxY - .draggOffset
      }
      
      collectionView.updateInteractiveMovementTargetPosition(location)
    case .ended:
      collectionView.endInteractiveMovement()
    default:
      collectionView.cancelInteractiveMovement()
    }
  }
  
  func didReorder(transaction: NSDiffableDataSourceTransaction<WalletsListSection, WalletsListItem>) {
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
    viewModel.didSelectItem(item)
  }
}

private extension NSCollectionLayoutSection {
  static var walletsSection: NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(.walletItemCellHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(.walletItemCellHeight)
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
    section.decorationItems = [
      NSCollectionLayoutDecorationItem.background(elementKind: WalletsListDecorationBackgroundView.reuseIdentifier)
    ]
    
    return section
  }
  static var addWalletSection: NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(.walletItemCellHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(.walletItemCellHeight)
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

private extension CGFloat {
  static let walletItemCellHeight: CGFloat = 76
  static let draggOffset: CGFloat = .walletItemCellHeight / 2
}
