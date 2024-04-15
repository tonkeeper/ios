import UIKit
import TKUIKit
import TKCoordinator

final class HistoryListViewController: GenericViewViewController<HistoryListView>, ScrollViewController {
  typealias SectionHeaderView = TKCollectionViewSupplementaryContainerView<TKListTitleView>
  typealias FooterView = TKCollectionViewSupplementaryContainerView<HistoryListFooterView>
  typealias ListShimmerView = TKCollectionViewSupplementaryContainerView<HistoryListShimmerView>
  
  private let viewModel: HistoryListViewModel
  
  private var headerViewController: UIViewController?
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
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
          return .shimmerSection()
        }
      },
      configuration: configuration
    )
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var historyCellConfiguration = UICollectionView.CellRegistration<HistoryCell, HistoryCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
  }
  
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
    guard scrollView.contentOffset.y > scrollView.adjustedContentInset.top else { return }
    scrollView.setContentOffset(
      CGPoint(x: 0,
              y: -scrollView.adjustedContentInset.top),
      animated: true
    )
  }
}

private extension HistoryListViewController {
  func setup() {
    customView.collectionView.delegate = self
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.register(
      TKReusableContainerView.self,
      forSupplementaryViewOfKind: .headerElementKind,
      withReuseIdentifier: TKReusableContainerView.reuseIdentifier
    )
    customView.collectionView.register(
      SectionHeaderView.self,
      forSupplementaryViewOfKind: .eventSectionHeaderElementKind,
      withReuseIdentifier: SectionHeaderView.reuseIdentifier
    )
    customView.collectionView.register(
      FooterView.self,
      forSupplementaryViewOfKind: .paginationSectionFooterElementKind,
      withReuseIdentifier: FooterView.reuseIdentifier
    )
    customView.collectionView.register(
      ListShimmerView.self,
      forSupplementaryViewOfKind: .shimmerSectionFooterElementKind,
      withReuseIdentifier: ListShimmerView.reuseIdentifier
    )
  }
  
  func setupBindings() {
    viewModel.didUpdateHistory = { [weak dataSource] sections in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      snapshot.deleteAllItems()
      for section in sections {
        switch section {
        case .events(let model):
          snapshot.appendSections([section])
          snapshot.appendItems(model.events, toSection: section)
        default:
          continue
        }
      }
      dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    viewModel.didStartPagination = { [weak dataSource] pagination in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      for id in snapshot.sectionIdentifiers {
        switch id {
        case .pagination:
          snapshot.deleteSections([id])
        default: continue
        }
      }
      snapshot.appendSections([.pagination(pagination)])
      dataSource.apply(snapshot)
    }
    
    viewModel.didStartLoading = { [weak dataSource] in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      snapshot.deleteAllItems()
      snapshot.appendSections([.shimmer])
      dataSource.apply(snapshot)
    }
    
    viewModel.didResetList = {  [weak dataSource] in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      snapshot.deleteAllItems()
      dataSource.apply(snapshot)
    }
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<HistoryListSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<HistoryListSection, AnyHashable>(
      collectionView: customView.collectionView) { [historyCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let configuration as HistoryCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: historyCellConfiguration, for: indexPath, item: configuration)
        default: return nil
        }
      }
    
    dataSource.supplementaryViewProvider = { [weak self, weak dataSource] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let dataSource else { return nil }
      if kind == .headerElementKind {
        let view = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: TKReusableContainerView.reuseIdentifier,
          for: indexPath
        ) as? TKReusableContainerView
        view?.setContentView(self?.headerViewController?.view)
        return view
      }
      
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      switch section {
      case .events(let model):
        let sectionHeaderView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: SectionHeaderView.reuseIdentifier,
          for: indexPath
        )
        (sectionHeaderView as? SectionHeaderView)?.configure(model: TKListTitleView.Model(title: model.title))
        return sectionHeaderView
      case .pagination(let pagination):
        let footerView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: FooterView.reuseIdentifier,
          for: indexPath
        )
        let state: HistoryListFooterView.State
        switch pagination {
        case .loading:
          state = .loading
        case .error(let title):
          state = .error(title: title, retryButtonAction: { [weak self] in
            self?.viewModel.loadNext()
          })
        }
        (footerView as? FooterView)?.configure(model: HistoryListFooterView.Model(state: state))
        return footerView
      case .shimmer:
        let shimmerView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: ListShimmerView.reuseIdentifier,
          for: indexPath
        )
        (shimmerView as? ListShimmerView)?.contentView.startAnimation()
        return shimmerView
      }
    }
    
    return dataSource
  }
  
  func fetchNextIfNeeded(collectionView: UICollectionView, indexPath: IndexPath) {
    let numberOfSections = collectionView.numberOfSections
    let numberOfItems = collectionView.numberOfItems(inSection: numberOfSections - 1)
    guard (indexPath.section == numberOfSections - 1) && (indexPath.item == numberOfItems - 1) else { return }
    viewModel.loadNext()
  }
}

extension HistoryListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView,
                      willDisplay cell: UICollectionViewCell,
                      forItemAt indexPath: IndexPath) {
    fetchNextIfNeeded(collectionView: collectionView, indexPath: indexPath)
  }
}

private extension String {
  static let headerElementKind = "HeaderElementKind"
  static let eventSectionHeaderElementKind = "EventSectionHeaderElementKind"
  static let paginationSectionFooterElementKind = "PaginationSectionFooterElementKind"
  static let shimmerSectionFooterElementKind = "ShimmerSectionFooterElementKind"
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
    
    let group = NSCollectionLayoutGroup.vertical(
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
    let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                                        heightDimension: .absolute(10)))
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(10)),
      subitems: [item]
    )
    let section = NSCollectionLayoutSection(group: group)
    let footerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(40)
    )
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: .paginationSectionFooterElementKind,
      alignment: .bottom
    )
    section.boundarySupplementaryItems = [footer]
    
    return section
  }
  
  static func shimmerSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                                        heightDimension: .absolute(10)))
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(10)),
      subitems: [item]
    )
    let section = NSCollectionLayoutSection(group: group)
    let footerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(100)
    )
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: .shimmerSectionFooterElementKind,
      alignment: .bottom
    )
    section.boundarySupplementaryItems = [footer]
    
    return section
  }
}
