import UIKit
import TKUIKit

enum SwapTokenListSection {
  case searchResults
  case suggestedTokens
  case otherTokens
  case shimmer
}

final class SwapTokenListViewController: ModalViewController<SwapTokenListView, ModalNavigationBarView>, KeyboardObserving {
  
  typealias ShimmerContainerView = TKCollectionViewSupplementaryContainerView<SwapTokenListShimmerView>
  typealias CellRegistration<T> = UICollectionView.CellRegistration<T, T.Configuration> where T: TKCollectionViewNewCell & TKConfigurableView
  typealias Snapshot = NSDiffableDataSourceSnapshot<SwapTokenListSection, AnyHashable>
  
  private var isSearching: Bool = false {
    didSet {
      guard isSearching != oldValue else { return }
      didUpdateSearchingState(newValue: isSearching)
    }
  }
  
  private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resignGestureAction))
    gestureRecognizer.cancelsTouchesInView = false
    gestureRecognizer.delegate = self
    return gestureRecognizer
  }()
  
  // MARK: - List
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .searchResults:
          return .searchResultsSection
        case .suggestedTokens:
          return .suggestedTokensSection
        case .otherTokens:
          return .otherTokensSection
        case .shimmer:
          return .shimmerSection
        }
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var suggestedTokenCellConfiguration: CellRegistration<SuggestedTokenCell> = createDefaultCellRegistration()
  private lazy var otherTokensCellConfiguration: CellRegistration<TKUIListItemCell> = createDefaultCellRegistration()
  
  private var preSearchSnapshot: Snapshot?
  
  // MARK: - Dependencies
  
  private let viewModel: SwapTokenListViewModel
  
  // MARK: - Init
  
  init(viewModel: SwapTokenListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
  
  // MARK: - View Life cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupCollectionView()
    setupBindings()
    setupGestures()
    setupViewEvents()
    
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    
    customView.collectionView.contentInset.top = ModalNavigationBarView.defaultHeight + customView.searchBarContainerHeight
    customView.collectionView.contentInset.bottom = customView.contentInsetBottom
    customView.searchBarViewTopOffset = ModalNavigationBarView.defaultHeight
    
    customNavigationBarView.leftItemPadding = 16
    customNavigationBarView.setupLeftBarItem(
      configuration: ModalNavigationBarView.BarItemConfiguration(
        view: customView.titleView,
        contentAlignment: .left
      )
    )
  }
  
  public func keyboardWillShow(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    guard let keyboardHeight = notification.keyboardSize?.height else { return }
    
    let contentInsetBottom = keyboardHeight - view.safeAreaInsets.bottom
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.collectionView.contentInset.bottom = contentInsetBottom
    }
  }
  
  public func keyboardWillHide(_ notification: Notification) {
    guard let animationDuration = notification.keyboardAnimationDuration else { return }
    
    let contentInsetBottom = customView.contentInsetBottom
    
    UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
      self.customView.collectionView.contentInset.bottom = contentInsetBottom
    }
  }
  
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    guard !(touch.view is SearchBar) else { return false }
    return true
  }
  
  @objc func resignGestureAction(sender: UITapGestureRecognizer) {
    view.endEditing(true)
  }
}

// MARK: - Setup

private extension SwapTokenListViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.collectionView.backgroundColor = .Background.page
  }
  
  func setupCollectionView() {
    customView.collectionView.delegate = self
    customView.collectionView.delaysContentTouches = false
    customView.collectionView.showsVerticalScrollIndicator = false
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    
    customView.collectionView.register(
      TitleHeaderCollectionView.self,
      forSupplementaryViewOfKind: .titleHeaderElementKind,
      withReuseIdentifier: TitleHeaderCollectionView.reuseIdentifier
    )
    
    customView.collectionView.register(
      ShimmerContainerView.self,
      forSupplementaryViewOfKind: .shimmerSectionFooterElementKind,
      withReuseIdentifier: ShimmerContainerView.reuseIdentifier
    )
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.shimmer])
    dataSource.apply(snapshot, animatingDifferences: false)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      self?.customView.configure(model: model)
    }
    
    viewModel.didUpdateListItems = { [weak self] suggestedTokenItems, otherTokenItems in
      guard let self else { return }
      
      if !isSearching {
        // Just update data source with new snapshot
        let snapshot = dataSource.snapshot()
        let hasShimmer = snapshot.sectionIdentifiers.contains(where: { $0 == .shimmer })
        let configuredSnapshot = configureDefaultSnapshot(
          snapshot: snapshot,
          suggestedTokenItems: suggestedTokenItems,
          otherTokenItems: otherTokenItems
        )
        dataSource.apply(configuredSnapshot, animatingDifferences: hasShimmer)
      } else if let snapshot = self.preSearchSnapshot {
        // Configure new preSearchSnapshot and don't apply new snapshot (don't cancel search)
        self.preSearchSnapshot = configureDefaultSnapshot(
          snapshot: snapshot,
          suggestedTokenItems: suggestedTokenItems,
          otherTokenItems: otherTokenItems
        )
      }
    }
    
    viewModel.didUpdateSearchResultsItems = { [weak self] searchResultsItems in
      guard let self else { return }
      
      let snapshot = configureSearchSnapshot(
        snapshot: dataSource.snapshot(),
        searchResultsItems: searchResultsItems
      )
      dataSource.apply(snapshot, animatingDifferences: false)
      
      customView.noSearchResultsLabel.isHidden = !searchResultsItems.isEmpty
    }
  }
  
  func setupGestures() {
    customView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  func setupViewEvents() {
    customView.searchBar.textDidChange = { [weak self] searchText in
      self?.isSearching = !searchText.isEmpty
      self?.viewModel.didInputSearchText(searchText)
    }
  }
  
  func configureDefaultSnapshot(snapshot: Snapshot,
                                suggestedTokenItems: [SuggestedTokenCell.Configuration],
                                otherTokenItems: [TKUIListItemCell.Configuration]) -> Snapshot {
    var newSnapshot = snapshot
    newSnapshot.prepareForItems(insSections: [.suggestedTokens, .otherTokens])
    newSnapshot.appendItems(suggestedTokenItems, toSection: .suggestedTokens)
    newSnapshot.appendItems(otherTokenItems, toSection: .otherTokens)
    return newSnapshot
  }
  
  func configureSearchSnapshot(snapshot: Snapshot,
                               searchResultsItems: [TKUIListItemCell.Configuration]) -> Snapshot {
    var newSnapshot = snapshot
    newSnapshot.prepareForItems(insSections: [.searchResults])
    newSnapshot.appendItems(searchResultsItems, toSection: .searchResults)
    return newSnapshot
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<SwapTokenListSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<SwapTokenListSection, AnyHashable>(
      collectionView: customView.collectionView) { [suggestedTokenCellConfiguration, otherTokensCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let cellConfiguration as SuggestedTokenCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: suggestedTokenCellConfiguration, for: indexPath, item: cellConfiguration)
        case let cellConfiguration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: otherTokensCellConfiguration, for: indexPath, item: cellConfiguration)
        default: return nil
        }
      }
    
    dataSource.supplementaryViewProvider = { [weak dataSource] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let dataSource else { return nil }
      
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      switch section {
      case .suggestedTokens:
        let titleHeaderView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: TitleHeaderCollectionView.reuseIdentifier,
          for: indexPath
        ) as? TitleHeaderCollectionView
        titleHeaderView?.configure(
          model: TitleHeaderCollectionView.Model(
            title: String.suggestedHeaderTitle.withTextStyle(.label1, color: .Text.primary)
          )
        )
        return titleHeaderView
      case .otherTokens:
        let titleHeaderView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: TitleHeaderCollectionView.reuseIdentifier,
          for: indexPath
        ) as? TitleHeaderCollectionView
        titleHeaderView?.configure(
          model: TitleHeaderCollectionView.Model(
            title: String.otherHeaderTitle.withTextStyle(.label1, color: .Text.primary)
          )
        )
        return titleHeaderView
      case .shimmer:
        let shimmerView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: ShimmerContainerView.reuseIdentifier,
          for: indexPath
        )
        (shimmerView as? ShimmerContainerView)?.contentView.startAnimation()
        return shimmerView
      default:
        return nil
      }
    }
    
    return dataSource
  }
  
  func createDefaultCellRegistration<T>() -> CellRegistration<T> {
    return CellRegistration<T> { [weak self]
      cell, indexPath, itemIdentifier in
      cell.configure(configuration: itemIdentifier)
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
    }
  }
  
  func didUpdateSearchingState(newValue: Bool) {
    if newValue {
      preSearchSnapshot = dataSource.snapshot()
    } else {
      if let preSearchSnapshot {
        customView.noSearchResultsLabel.isHidden = true
        dataSource.apply(preSearchSnapshot, animatingDifferences: false)
        self.preSearchSnapshot = nil
      } else {
        viewModel.reloadListItems()
      }
    }
  }
}

// MARK: - UICollectionViewDelegate

extension SwapTokenListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    
    switch item {
    case let model as SuggestedTokenCell.Configuration:
      model.selectionClosure?()
    case let model as TKUIListItemCell.Configuration:
      model.selectionClosure?()
    default:
      break
    }
  }
}

extension NSDiffableDataSourceSnapshot {
  mutating func prepareForItems(insSections sections: [SectionIdentifierType]) {
    if self.sectionIdentifiers == sections {
      sections.forEach { self.deleteItems(self.itemIdentifiers(inSection: $0)) }
    } else {
      self.deleteSections(self.sectionIdentifiers)
      self.appendSections(sections)
    }
  }
}

private extension NSCollectionLayoutSection {
  static var searchResultsSection: NSCollectionLayoutSection {
    return .createSection(cellHeight: .tokenCellListHeight)
  }
  
  static var suggestedTokensSection: NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .estimated(100),
      heightDimension: .absolute(.suggestedTokenCellHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)

    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1),
      heightDimension: itemLayoutSize.heightDimension
    )
    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupLayoutSize, subitems: [item])
    group.interItemSpacing = .fixed(.suggestedTokenInterGroupSpacing)
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .init(top: 0, leading: 16, bottom: 16, trailing: 16)
    section.interGroupSpacing = 8
    section.boundarySupplementaryItems = [.createTitleHeaderItem()]
    return section
  }
  
  static var otherTokensSection: NSCollectionLayoutSection {
    let section = NSCollectionLayoutSection.createSection(cellHeight: .tokenCellListHeight)
    section.boundarySupplementaryItems = [.createTitleHeaderItem()]
    return section
  }
  
  static var shimmerSection: NSCollectionLayoutSection {
    let section = NSCollectionLayoutSection.createSection(
      cellHeight: 100,
      contentInsets: .init(top: 0, leading: 16, bottom: 0, trailing: 16)
    )
    let footerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(400)
    )
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: .shimmerSectionFooterElementKind,
      alignment: .bottom
    )
    section.boundarySupplementaryItems = [footer]
    return section
  }
  
  static func createSection(cellHeight: CGFloat,
                          contentInsets: NSDirectionalEdgeInsets = .defaultSectionInsets) -> NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(cellHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(cellHeight)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = contentInsets
    return section
  }
}

private extension NSCollectionLayoutBoundarySupplementaryItem {
  static func createTitleHeaderItem() -> NSCollectionLayoutBoundarySupplementaryItem {
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(.titleHeaderHeight)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: .titleHeaderElementKind,
      alignment: .top
    )
    header.contentInsets = .init(top: 0, leading: 2, bottom: 0, trailing: 2)
    return header
  }
}

private extension String {
  static let suggestedHeaderTitle = "Suggested"
  static let otherHeaderTitle = "Other"
  static let titleHeaderElementKind = "TitleHeaderElementKind"
  static let shimmerSectionFooterElementKind = "ShimmerSectionFooterElementKind"
}

private extension NSDirectionalEdgeInsets {
  static let defaultSectionInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
}

private extension CGFloat {
  static let titleHeaderHeight: CGFloat = 48
  static let suggestedTokenInterGroupSpacing: CGFloat = 8
  static let suggestedTokenCellHeight: CGFloat = 36
  static let tokenCellListHeight: CGFloat = 76
}
