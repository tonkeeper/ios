import UIKit
import TKUIKit

final class HistoryListCollectionController: NSObject {
  typealias DataSource = UICollectionViewDiffableDataSource<HistoryListSection, AnyHashable>
  typealias SectionHeaderView = TKCollectionViewSupplementaryContainerView<TKListTitleView>
  typealias FooterView = TKCollectionViewSupplementaryContainerView<HistoryListFooterView>
  typealias ListShimmerView = TKCollectionViewSupplementaryContainerView<HistoryListShimmerView>
  
  typealias HistoryCellRegistration = UICollectionView.CellRegistration<HistoryEventCell, HistoryEventCell.Model>
  
  var loadNextPage: (() -> Void)?
  
  private var paginationSection: HistoryListSection?
  
  private let collectionView: UICollectionView
  private let headerViewProvider: () -> UIView?
  private let dataSource: DataSource
  
  private let historyCellRegistration: HistoryCellRegistration
  
  init(collectionView: UICollectionView,
       headerViewProvider: @escaping () -> UIView?) {
    self.collectionView = collectionView
    self.headerViewProvider = headerViewProvider
    
    let historyCellRegistration = HistoryCellRegistration(handler: { cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    })

    let dataSource = DataSource(
      collectionView: collectionView,
      cellProvider: { collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let model as HistoryEventCell.Model:
          return collectionView.dequeueConfiguredReusableCell(
            using: historyCellRegistration,
            for: indexPath,
            item: model)
        default:
          return nil
        }
      }
    )
    
    self.dataSource = dataSource
    self.historyCellRegistration = historyCellRegistration
    
    super.init()
    
    dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
      self?.dequeueSupplementaryView(collectionView: collectionView, kind: kind, indexPath: indexPath)
    }
    
    let layout = HistoryListCollectionLayout.layout { sectionIndex in
      return dataSource.snapshot().sectionIdentifiers[sectionIndex]
    }
    
    collectionView.setCollectionViewLayout(layout, animated: false)
    
    collectionView.delegate = self
    
    collectionView.register(
      SectionHeaderView.self,
      forSupplementaryViewOfKind: HistoryListSupplementaryItem.sectionHeader.rawValue,
      withReuseIdentifier: SectionHeaderView.reuseIdentifier
    )
    collectionView.register(
      FooterView.self,
      forSupplementaryViewOfKind: HistoryListSupplementaryItem.footer.rawValue,
      withReuseIdentifier: FooterView.reuseIdentifier
    )
    collectionView.register(
      CollectionViewSupplementaryContainerView.self,
      forSupplementaryViewOfKind: HistoryListSupplementaryItem.header.rawValue,
      withReuseIdentifier: CollectionViewSupplementaryContainerView.reuseIdentifier
    )
    collectionView.register(
      ListShimmerView.self,
      forSupplementaryViewOfKind: HistoryListSupplementaryItem.shimmer.rawValue,
      withReuseIdentifier: ListShimmerView.reuseIdentifier
    )
  }
  
  func setSections(_ sections: [HistoryListSection]) {
    var snapshot = dataSource.snapshot()
    snapshot.deleteAllItems()
    snapshot.appendSections(sections)
    for section in sections {
      switch section {
      case .events(let sectionModel):
        snapshot.appendItems(sectionModel.events, toSection: section)
      case .shimmer:
        continue
      case .pagination:
        continue
      }
    }
    UIView.performWithoutAnimation {
      dataSource.apply(snapshot)
    }
  }
  
  func showPagination(_ pagination: HistoryListSection.Pagination) {
    var snapshot = dataSource.snapshot()
    if let paginationSection = paginationSection {
      snapshot.deleteSections([paginationSection])
    }
    let updatedPagination = HistoryListSection.pagination(pagination)
    self.paginationSection = updatedPagination
    snapshot.appendSections([updatedPagination])
    UIView.performWithoutAnimation {
      dataSource.apply(snapshot)
    }
  }
  
  func showShimmer() {
    var snapshot = NSDiffableDataSourceSnapshot<HistoryListSection, AnyHashable>()
    snapshot.appendSections([.shimmer])
    UIView.performWithoutAnimation {
      dataSource.apply(snapshot)
    }
  }
}

private extension HistoryListCollectionController {
  func fetchNextIfNeeded(collectionView: UICollectionView, indexPath: IndexPath) {
    let numberOfSections = collectionView.numberOfSections
    let numberOfItems = collectionView.numberOfItems(inSection: numberOfSections - 1)
    guard (indexPath.section == numberOfSections - 1) && (indexPath.item == numberOfItems - 1) else { return }
    loadNextPage?()
  }
  
  func dequeueSupplementaryView(collectionView: UICollectionView, 
                                kind: String,
                                indexPath: IndexPath) -> UICollectionReusableView? {
    if HistoryListSupplementaryItem(rawValue: kind) == .header {
      let headerView = collectionView.dequeueReusableSupplementaryView(
        ofKind: kind,
        withReuseIdentifier: CollectionViewSupplementaryContainerView.reuseIdentifier,
        for: indexPath
      )
      (headerView as? CollectionViewSupplementaryContainerView)?.setContentView(headerViewProvider())
      return headerView
    }
    let snapshot = self.dataSource.snapshot()
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
          self?.loadNextPage?()
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
}

extension HistoryListCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, 
                      willDisplay cell: UICollectionViewCell,
                      forItemAt indexPath: IndexPath) {
    fetchNextIfNeeded(collectionView: collectionView, indexPath: indexPath)
  }
}
