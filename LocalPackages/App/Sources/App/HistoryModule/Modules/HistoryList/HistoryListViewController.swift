import UIKit
import TKUIKit
import TKCoordinator

final class HistoryListViewController: GenericViewViewController<HistoryListView>, ContentListEmptyViewControllerListViewController {
  typealias EventCellConfiguration = UICollectionView.CellRegistration<HistoryCell, HistoryList.EventID>
  typealias PaginationCellConfiguration = UICollectionView.CellRegistration<HistoryListPaginationCell, HistoryListPaginationCell.Model>
  typealias ShimmerCellConfiguration = UICollectionView.CellRegistration<HistoryListShimmerCell, HistoryListShimmerCell.Model>
  typealias ContainerViewConfiguration = UICollectionView.SupplementaryRegistration<TKReusableContainerView>
  typealias EventSectionHeaderView = TKCollectionViewSupplementaryContainerView<TKListTitleView>
  typealias EventSectionHeaderConfiguration = UICollectionView.SupplementaryRegistration<EventSectionHeaderView>
  
  private lazy var dataSource = setupDataSource()
  private lazy var layout = setupLayout()
  
  private var headerViewController: UIViewController?

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
    
    setup()
    setupBindings()
    
    viewModel.viewDidLoad()
  }
  
  func setHeaderViewController(_ headerViewController: UIViewController?) {
    self.headerViewController?.willMove(toParent: nil)
    self.headerViewController?.removeFromParent()
    self.headerViewController?.didMove(toParent: nil)
    self.headerViewController = headerViewController
    if let headerViewController = headerViewController {
      addChild(headerViewController)
    }
    headerViewController?.didMove(toParent: self)
    customView.collectionView.reloadData()
  }
  
  func scrollToTop() {
    guard customView.collectionView.contentOffset.y > customView.collectionView.adjustedContentInset.top else { return }
    customView.collectionView.setContentOffset(
      CGPoint(x: 0,
              y: -customView.collectionView.adjustedContentInset.top),
      animated: true
    )
  }
}

private extension HistoryListViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    customView.collectionView.prefetchDataSource = self
  
    setupBindings()
  }
  
  func setupBindings() {
    viewModel.eventHandler = { [weak self] event in
      guard let self else { return }
      switch event {
      case .snapshotUpdate(let snapshot):
        self.dataSource.apply(snapshot, animatingDifferences: false)
      }
    }
  }
  
  func setupLayout() -> UICollectionViewCompositionalLayout {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: size,
      elementKind: .headerElementKind,
      alignment: .top
    )
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.boundarySupplementaryItems = [header]
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .events:
          return .eventsSection
        case .pagination:
          return .paginationSection
        case .shimmer:
          return .shimmerSection
        }
      },
      configuration: configuration
    )
    return layout
  }
  
  func setupDataSource() -> HistoryList.DataSource {
    let eventCellConfiguration = EventCellConfiguration {
      [weak viewModel] cell, indexPath, itemIdentifier in
      guard let model = viewModel?.getEventCellConfiguration(eventID: itemIdentifier) else { return }
      cell.configure(model: model)
    }
    
    let paginationCellConfiguration = PaginationCellConfiguration {
      cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    }
    
    let shimmerCellConfiguration = ShimmerCellConfiguration {
      cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    }
    
    let dataSource = HistoryList.DataSource(collectionView: customView.collectionView) { [weak self]
      collectionView, indexPath, itemIdentifier in
      guard let self else { return nil }
      switch itemIdentifier {
      case .event(let eventId):
        return collectionView.dequeueConfiguredReusableCell(
          using: eventCellConfiguration,
          for: indexPath,
          item: eventId)
      case .pagination:
        return collectionView.dequeueConfiguredReusableCell(
          using: paginationCellConfiguration,
          for: indexPath,
          item: viewModel.getPaginationCellConfiguration())
      case .shimmer:
        return collectionView.dequeueConfiguredReusableCell(
          using: shimmerCellConfiguration,
          for: indexPath,
          item: HistoryListShimmerCell.Model())
      }
    }
    
    let containerViewConfiguration = ContainerViewConfiguration(elementKind: .headerElementKind) { [weak self] supplementaryView, elementKind, indexPath in
      supplementaryView.setContentView(self?.headerViewController?.view)
    }
    
    let eventSectionHeaderConfiguration = EventSectionHeaderConfiguration(elementKind: .eventSectionHeaderElementKind) {
      [weak dataSource, weak viewModel] supplementaryView, elementKind, indexPath in
      guard let dataSource else { return }
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      switch section {
      case .events(let eventsSection):
        supplementaryView.configure(
          model: TKListTitleView.Model(
            title: viewModel?.getSectionHeaderTitle(sectionID: eventsSection),
            textStyle: .h3
          )
        )
      case .pagination, .shimmer:
        return
      }
    }
    
    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in
      switch kind {
      case .headerElementKind:
        return collectionView.dequeueConfiguredReusableSupplementary(using: containerViewConfiguration, for: indexPath)
      case .eventSectionHeaderElementKind:
        return collectionView.dequeueConfiguredReusableSupplementary(using: eventSectionHeaderConfiguration, for: indexPath)
      default:
        return nil
      }
    }
    
    return dataSource
  }
}
  
private extension NSCollectionLayoutSection {

  static var eventsSection: NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 8
    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
    
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(56)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: .eventSectionHeaderElementKind,
      alignment: .top
    )
    section.boundarySupplementaryItems = [header]
    
    return section
  }
  
  static var paginationSection: NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(40)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(40)
    )
    
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupSize,
      subitems: [item]
    )
    let section = NSCollectionLayoutSection(group: group)
    return section
  }
  
  static var shimmerSection: NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(100)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(100)
    )
    
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupSize,
      subitems: [item]
    )
    let section = NSCollectionLayoutSection(group: group)
    return section
  }
}

extension HistoryListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, 
                      willDisplay cell: UICollectionViewCell,
                      forItemAt indexPath: IndexPath) {
    (cell as? HistoryListShimmerCell)?.startAnimation()
    
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    guard case .pagination = section else {
      return
    }
    viewModel.loadNextPage()
  }
  
  func collectionView(_ collectionView: UICollectionView, 
                      didEndDisplaying cell: UICollectionViewCell,
                      forItemAt indexPath: IndexPath) {
    (cell as? HistoryListShimmerCell)?.stopAnimation()
  }
}

extension HistoryListViewController: UICollectionViewDataSourcePrefetching {
  func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      guard case .pagination = section else {
        continue
      }
      viewModel.loadNextPage()
    }
  }
}

private extension String {
  static let headerElementKind = "HeaderElementKind"
  static let eventSectionHeaderElementKind = "EventSectionHeaderElementKind"
}
