import UIKit
import TKUIKit

enum SwapTokenListSection {
//  case searchResults
  case suggestedTokens
  case otherTokens
}

final class SwapTokenListViewController: ModalViewController<SwapTokenListView, ModalNavigationBarView>, KeyboardObserving {
  
  typealias CellRegistration<T> = UICollectionView.CellRegistration<T, T.Configuration> where T: TKCollectionViewNewCell & TKConfigurableView
  
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
        case .suggestedTokens:
          return .suggestedTokensSection
        case .otherTokens:
          return .otherTokensSection
        }
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var suggestedTokenCellConfiguration: CellRegistration<SuggestedTokenCell> = createDefaultCellRegistration()
  private lazy var otherTokensCellConfiguration: CellRegistration<TKUIListItemCell> = createDefaultCellRegistration()
  
  private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resignGestureAction))
    gestureRecognizer.cancelsTouchesInView = false
    return gestureRecognizer
  }()
  
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
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    
    customView.collectionView.contentInset.top = ModalNavigationBarView.defaultHeight + customView.searchBarContainerHeight
    customView.searchBarViewTopOffset = ModalNavigationBarView.defaultHeight
    
    customNavigationBarView.leftItemPadding = 16
    customNavigationBarView.setupLeftBarItem(
      configuration: ModalNavigationBarView.BarItemConfiguration(
        view: customView.titleView,
        contentAlignment: .left
      )
    )
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
    customView.collectionView.allowsMultipleSelection = true
    customView.collectionView.showsVerticalScrollIndicator = false
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    
    customView.collectionView.register(
      TKReusableContainerView.self,
      forSupplementaryViewOfKind: .searchBarElementKind,
      withReuseIdentifier: TKReusableContainerView.reuseIdentifier
    )
    
    customView.collectionView.register(
      TitleHeaderCollectionView.self,
      forSupplementaryViewOfKind: .titleHeaderElementKind,
      withReuseIdentifier: TitleHeaderCollectionView.reuseIdentifier
    )
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.suggestedTokens])
    snapshot.appendSections([.otherTokens])
    dataSource.apply(snapshot, animatingDifferences: false)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      
      customView.titleView.configure(model: .init(title: model.title))
      
      customView.closeButton.configuration.content = TKButton.Configuration.Content(title: .plainString(model.closeButton.title))
      customView.closeButton.configuration.action = model.closeButton.action
    }
    
    viewModel.didUpdateListItems = { [weak self] suggestedTokenItems, otherTokenItems in
      guard let dataSource = self?.dataSource else { return }
      
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .suggestedTokens))
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .otherTokens))
      snapshot.appendItems(suggestedTokenItems, toSection: .suggestedTokens)
      snapshot.appendItems(otherTokenItems, toSection: .otherTokens)
      dataSource.apply(snapshot,animatingDifferences: false)
    }
  }
  
  func setupGestures() {
    customView.addGestureRecognizer(tapGestureRecognizer)
  }
  
  func setupViewEvents() {
    customView.searchBar.textDidChange = { [weak self] searchText in
      self?.viewModel.didInputSearchText(searchText)
    }
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
            title: "Suggested".withTextStyle(.label1, color: .Text.primary)
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
            title: "Other".withTextStyle(.label1, color: .Text.primary)
          )
        )
        return titleHeaderView
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
  
  @objc func resignGestureAction(sender: UITapGestureRecognizer) {
    let touchLocation = sender.location(in: customView.searchBarContainer)
    let isTapInSearchBar = customView.searchBar.frame.contains(touchLocation)
    
    guard !isTapInSearchBar else { return }
    
    customView.searchBar.resignFirstResponder()
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

private extension NSCollectionLayoutSection {
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
    let section = NSCollectionLayoutSection.createSection(cellHeight: .otherTokenCellHeight)
    section.boundarySupplementaryItems = [.createTitleHeaderItem()]
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
  static let searchBarElementKind = "SearchBarElementKind"
  static let titleHeaderElementKind = "TitleHeaderElementKind"
}

private extension NSDirectionalEdgeInsets {
  static let defaultSectionInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
}

private extension CGFloat {
  static let titleHeaderHeight: CGFloat = 48
  static let suggestedTokenInterGroupSpacing: CGFloat = 8
  static let suggestedTokenCellHeight: CGFloat = 36
  static let otherTokenCellHeight: CGFloat = 76
}
