import UIKit
import TKUIKit

final class WalletBalanceCollectionController: TKCollectionController<WalletBalanceSection, AnyHashable> {
  
  typealias BalanceCellRegistration = UICollectionView.CellRegistration<WalletBalanceBalanceItemCell, WalletBalanceBalanceItemCell.Model>
  typealias SectionHeaderView = TKCollectionViewSupplementaryContainerView<TKListTitleView>
  
  private let balanceCellRegistration: BalanceCellRegistration
  
  init(collectionView: UICollectionView,
       headerViewProvider: (() -> UIView)? = nil, 
       footerViewProvider: (() -> UIView)? = nil) {
    let balanceCellRegistration = BalanceCellRegistration { cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    }
    self.balanceCellRegistration = balanceCellRegistration
    
    super.init(
      collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let model as WalletBalanceBalanceItemCell.Model:
          let cell = collectionView.dequeueConfiguredReusableCell(using: balanceCellRegistration, for: indexPath, item: model)
          cell.isFirstInSection = { return $0.item == 0 }
          cell.isLastInSection = { [unowned collectionView] in
            let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
            return $0.item == numberOfItems - 1
          }
          return cell
        default: return nil
        }
      },
      headerViewProvider: headerViewProvider)
    
    collectionView.setCollectionViewLayout(TKCollectionLayout.layout(sectionLayout: { [weak self] sectionIndex in
      guard let self = self else { return nil }
      let section = dataSource.snapshot().sectionIdentifiers[sectionIndex]
      switch section {
      case .balanceItems:
        return balanceItemsSectionLayout()
      case .finishSetup:
        return finishSetupSectionLayout()
      }
    }), animated: false)
    
    supplementaryViewProvider = { collectionView, kind, indexPath in
      switch WalletBalanceCollectionSupplementaryItem(rawValue: kind) {
      case .sectionHeader:
        let snapshot = self.dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let sectionHeaderView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: SectionHeaderView.reuseIdentifier,
          for: indexPath
        )
        (sectionHeaderView as? SectionHeaderView)?.configure(model: TKListTitleView.Model(title: section.title))
        return sectionHeaderView
      case .none: return nil
      }
    }
    
    collectionView.contentInset.bottom = 16
    
    collectionView.register(
      SectionHeaderView.self,
      forSupplementaryViewOfKind: WalletBalanceCollectionSupplementaryItem.sectionHeader.rawValue,
      withReuseIdentifier: SectionHeaderView.reuseIdentifier
    )
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.balanceItems])
    dataSource.apply(snapshot, animatingDifferences: false)
  }
  
  func setBalanceItems(_ items: [AnyHashable]) {
    var snapshot = dataSource.snapshot()
    snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .balanceItems))
    snapshot.appendItems(items, toSection: .balanceItems)
    snapshot.reloadSections([.balanceItems])
    UIView.performWithoutAnimation {
      dataSource.apply(snapshot, animatingDifferences: true)
    }
  }
  
  func setFinishSetupItems(_ items: [AnyHashable]) {
    var snapshot = dataSource.snapshot()
    snapshot.deleteSections([.finishSetup])
    if !items.isEmpty {
      snapshot.appendSections([.finishSetup])
      snapshot.appendItems(items, toSection: .finishSetup)
      snapshot.reloadSections([.finishSetup])
    }
    UIView.performWithoutAnimation {
      dataSource.apply(snapshot, animatingDifferences: true)
    }
  }
}

private extension WalletBalanceCollectionController {
  func dequeueSupplementaryView(collectionView: UICollectionView,
                                kind: String,
                                indexPath: IndexPath) -> UICollectionReusableView? {
    switch WalletBalanceCollectionSupplementaryItem(rawValue: kind) {
    case .sectionHeader:
      let snapshot = self.dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      let sectionHeaderView = collectionView.dequeueReusableSupplementaryView(
        ofKind: kind,
        withReuseIdentifier: SectionHeaderView.reuseIdentifier,
        for: indexPath
      )
      (sectionHeaderView as? SectionHeaderView)?.configure(model: TKListTitleView.Model(title: section.title))
      return sectionHeaderView

    case .none: return nil
    }
//    if HistoryListSupplementaryItem(rawValue: kind) == .header {
//      let headerView = collectionView.dequeueReusableSupplementaryView(
//        ofKind: kind,
//        withReuseIdentifier: CollectionViewSupplementaryContainerView.reuseIdentifier,
//        for: indexPath
//      )
//      (headerView as? CollectionViewSupplementaryContainerView)?.setContentView(headerViewProvider())
//      return headerView
//    }
//    let snapshot = self.dataSource.snapshot()
//    let section = snapshot.sectionIdentifiers[indexPath.section]
//    switch section {
//    case .events(let model):
//      let sectionHeaderView = collectionView.dequeueReusableSupplementaryView(
//        ofKind: kind,
//        withReuseIdentifier: SectionHeaderView.reuseIdentifier,
//        for: indexPath
//      )
//      (sectionHeaderView as? SectionHeaderView)?.configure(model: TKListTitleView.Model(title: model.title))
//      return sectionHeaderView
//    case .pagination(let pagination):
//      let footerView = collectionView.dequeueReusableSupplementaryView(
//        ofKind: kind,
//        withReuseIdentifier: FooterView.reuseIdentifier,
//        for: indexPath
//      )
//      let state: HistoryListFooterView.State
//      switch pagination {
//      case .loading:
//        state = .loading
//      case .error(let title):
//        state = .error(title: title, retryButtonAction: { [weak self] in
//          self?.loadNextPage?()
//        })
//      }
//      (footerView as? FooterView)?.configure(model: HistoryListFooterView.Model(state: state))
//      return footerView
//    case .shimmer:
//      let shimmerView = collectionView.dequeueReusableSupplementaryView(
//        ofKind: kind,
//        withReuseIdentifier: ListShimmerView.reuseIdentifier,
//        for: indexPath
//      )
//      (shimmerView as? ListShimmerView)?.contentView.startAnimation()
//      return shimmerView
//    }
  }
  
  func balanceItemsSectionLayout() -> NSCollectionLayoutSection {
    return TKCollectionLayout.listSectionLayout(
      padding: NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16),
      heightDimension: .absolute(76))
  }
  
  func finishSetupSectionLayout() -> NSCollectionLayoutSection {
    let section = TKCollectionLayout.listSectionLayout(
      padding: NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16),
      heightDimension: .absolute(76))
    
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(56)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: HistoryListSupplementaryItem.sectionHeader.rawValue,
      alignment: .top
    )
    section.boundarySupplementaryItems = [header]
    
    return section
  }
}
