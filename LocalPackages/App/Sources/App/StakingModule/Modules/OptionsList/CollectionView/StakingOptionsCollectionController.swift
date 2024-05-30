import UIKit
import TKUIKit
import Foundation

struct StakingOptionSection: Hashable {
  let title: String
  let items: [TKUIListItemCell.Configuration]
  
  init(title: String, items: [TKUIListItemCell.Configuration]) {
    self.title = title
    self.items = items
  }
}

final class StakingOptionsListCollectionController: TKCollectionController<StakingOptionSection, AnyHashable> {
  typealias SectionHeaderView = TKCollectionViewSupplementaryContainerView<TKListTitleView>
  typealias OptionsCellRegistration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration>
  typealias SectionHeaderRegistration = UICollectionView.SupplementaryRegistration
  <CollectionViewSupplementaryContainerView>
  
  private let optionCellRegistration: OptionsCellRegistration
  private var sectionHeaderRegistration: SectionHeaderRegistration?
  
  init(collectionView: UICollectionView) {
    let optionCellRegistration = OptionsCellRegistration { cell, indexPath, itemIdentifier in
      cell.configure(configuration: itemIdentifier)
      cell.isFirstInSection = { $0.item == 0 }
      cell.isLastInSection = { $0.item == collectionView.lastItemIndex(inSection: $0.section) }
    }
    self.optionCellRegistration = optionCellRegistration
    
    super.init(
        collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
            switch itemIdentifier {
            case let model as TKUIListItemCell.Configuration:
                let cell = collectionView.dequeueConfiguredReusableCell(using: optionCellRegistration, for: indexPath, item: model)
                return cell
            default: return nil
            }
        }
    )
    
    let headerRegistration = SectionHeaderRegistration(
      elementKind: .stakingOptionSsectionHeaderElementKind
    ) { [weak self] supplementaryView, elementKind, indexPath in
      guard let self else {
        return
      }
      
      let snapshot = self.dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      
      let titleView = TKListTitleView()
      titleView.configure(model: .init(title: section.title, textStyle: .h3))
      supplementaryView.setContentView(titleView)
    }
    self.sectionHeaderRegistration = headerRegistration

    self.supplementaryViewProvider = { collectionView, elementKind, indexPath in
      switch elementKind {
      case .stakingOptionSsectionHeaderElementKind:
        let cell = collectionView.dequeueConfiguredReusableSupplementary(
          using: headerRegistration,
          for: indexPath
        )
        
        return cell
      default:
        return nil
      }
    }
    
    let layout = StakingOptionsCollectionLayout.layout
    collectionView.setCollectionViewLayout(layout, animated: false)
    collectionView.contentInset.bottom = .scrollViewBottomInset
}
  
  func setOptionSections(_ sections: [StakingOptionSection]) {
    var snapshot = dataSource.snapshot()
    snapshot.deleteAllItems()
    
    snapshot.appendSections(sections)
    for section in sections {
      snapshot.appendItems(section.items, toSection: section)
    }
    
    dataSource.apply(snapshot, animatingDifferences: false)
  }
}

private extension CGFloat {
  static let scrollViewBottomInset: Self = 16
}

private extension UICollectionView {
  func lastItemIndex(inSection section: Int) -> Int {
    numberOfItems(inSection: section) - 1
  }
}
