import UIKit
import TKUIKit
import TKLocalize

final class ManageTokensViewController: GenericViewViewController<ManageTokensView>, TKBottomSheetScrollContentViewController {
  typealias HeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListTitleView>>
  
  private let viewModel: ManageTokensViewModel
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { _, _ in
        return .walletsSection
      },
      configuration: configuration
    )
    
    layout.register(
      WalletsListDecorationBackgroundView.self, 
      forDecorationViewOfKind: WalletsListDecorationBackgroundView.reuseIdentifier
    )
    
    return layout
  }()

  private lazy var dataSource = createDataSource()

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
}

private extension ManageTokensViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    customView.collectionView.addGestureRecognizer(reorderGesture)
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<ManageTokensSection, ManageTokensItem> {
    let tokenCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, ManageTokensItem> {
      [weak self] cell, indexPath, identifier in
      guard let self else { return }
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { [weak collectionView = self.customView.collectionView] ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
      
      if let model = self.viewModel.getItemModel(item: identifier) {
        cell.configure(configuration: model.configuration)
        setCellAccessoryViews(item: identifier, state: model.state, cell: cell)
      }
    }
    
    let dataSource = UICollectionViewDiffableDataSource<ManageTokensSection, ManageTokensItem>(
      collectionView: customView.collectionView) {
        collectionView,
        indexPath,
        itemIdentifier in
        let cell = collectionView.dequeueConfiguredReusableCell(
          using: tokenCellConfiguration,
          for: indexPath,
          item: itemIdentifier
        )
        return cell
      }
    
    let setupSectionHeaderRegistration = sectionHeaderRegistration()
    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in
      switch kind {
      case .sectionHeaderElementKind:
        return collectionView.dequeueConfiguredReusableSupplementary(using: setupSectionHeaderRegistration, for: indexPath)
      default: return nil
      }
    }
    
    dataSource.reorderingHandlers.canReorderItem = { [weak self] itemIdentifier in
      guard let self,
            let model = self.viewModel.getItemModel(item: itemIdentifier) else { return false}
      switch model.state {
      case .pinned:
        return true
      case .unpinned:
        return false
      }
    }
    
    dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
      self?.didReorder(transaction: transaction)
    }
    
    return dataSource
  }
  
  func sectionHeaderRegistration() -> HeaderRegistration {
    HeaderRegistration(elementKind: .sectionHeaderElementKind) { [weak self] supplementaryView, elementKind, indexPath in
      guard let self else { return }
      let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
      switch section {
      case .pinned:
        supplementaryView.configure(
          model: TKListTitleView.Model(
            title: TKLocales.HomeScreenConfiguration.Sections.pinned,
            textStyle: .label1)
        )
      case .allAsstes:
        supplementaryView.configure(
          model: TKListTitleView.Model(
            title: TKLocales.HomeScreenConfiguration.Sections.all_assets,
            textStyle: .label1)
        )
      }
    }
  }
  
  private func setCellAccessoryViews(item: ManageTokensItem, state: ManageTokensItemState, cell: TKUIListItemCell) {
    switch state {
    case .pinned:
      cell.accessoryViews = [
        createPinAcessoryView(
          item: item,
          isOn: true
        ),
        createReorderAcessoryView()
      ]
    case .unpinned(let isHidden):
      if isHidden {
        cell.accessoryViews = [createHiddenAccessoryView(item: item)]
      } else {
        cell.accessoryViews = [
          createPinAcessoryView(
            item: item,
            isOn: false
          ),
          createVisibleAccessoryView(item: item)
        ]
      }
    }
  }
  
  func createPinAcessoryView(item: ManageTokensItem, isOn: Bool) -> UIView {
    createAccessoryView(
      image: .TKUIKit.Icons.Size28.pin,
      tintColor: isOn ? .Accent.blue : .Icon.tertiary,
      tapClosure: { [weak self] in
        if isOn {
          self?.viewModel.unpinItem(item: item)
        } else {
          self?.viewModel.pinItem(item: item)
        }
      }
    )
  }
  
  func createReorderAcessoryView() -> UIView {
    createAccessoryView(
      image: .TKUIKit.Icons.Size28.reorder,
      tintColor: .Icon.secondary,
      tapClosure: nil
    )
  }
  
  func createVisibleAccessoryView(item: ManageTokensItem) -> UIView {
    createAccessoryView(
      image: .TKUIKit.Icons.Size28.eyeOutline,
      tintColor: .Accent.blue,
      tapClosure: { [weak self] in
        self?.viewModel.hideItem(item: item)
      }
    )
  }
  
  func createHiddenAccessoryView(item: ManageTokensItem) -> UIView {
    createAccessoryView(
      image: .TKUIKit.Icons.Size28.eyeClosedOutline,
      tintColor: .Icon.tertiary,
      tapClosure: {[weak self] in
        self?.viewModel.unhideItem(item: item)
      }
    )
  }

  func createAccessoryView(image: UIImage,
                           tintColor: UIColor,
                           tapClosure: (() -> Void)?) -> UIView {
    var configuration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    configuration.contentPadding.right = 16
    configuration.iconTintColor = tintColor
    configuration.content.icon = image
    let button = TKButton(configuration: configuration)
    if let tapClosure {
      button.configuration.action = tapClosure
    } else {
      button.isUserInteractionEnabled = false
    }
    return button
  }
 
  func setupBindings() {
    viewModel.didUpdateTitle = { [weak self] title in
      self?.title = title
    }
    
    viewModel.didUpdateSnapshot = { [weak self] snapshot, isAnimated in
      self?.dataSource.apply(snapshot, animatingDifferences: isAnimated)
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
  
  func didReorder(transaction: NSDiffableDataSourceTransaction<ManageTokensSection, ManageTokensItem>) {
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
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(48)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: .sectionHeaderElementKind,
      alignment: .top
    )
    section.boundarySupplementaryItems = [header]
    
    return section
  }
}

private extension CGFloat {
  static let walletItemCellHeight: CGFloat = 76
  static let draggOffset: CGFloat = .walletItemCellHeight / 2
}

private extension String {
  static let sectionHeaderElementKind = "SectionHeaderElementKind"
}
