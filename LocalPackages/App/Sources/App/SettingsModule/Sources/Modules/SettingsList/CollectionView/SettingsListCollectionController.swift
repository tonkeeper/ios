import UIKit
import TKUIKit

final class SettingsListCollectionController: TKCollectionController<SettingsListSection, AnyHashable> {
  
  typealias SettingsIconCellRegistration = UICollectionView.CellRegistration<SettingsCell, SettingsCell.Model>
  
  private let settingsIconCellRegistration: SettingsIconCellRegistration
  
  init(collectionView: UICollectionView,
       cellProvider: ((UICollectionView, IndexPath, AnyHashable) -> TKCollectionViewCell?)? = nil) {
    let settingsIconCellRegistration = SettingsIconCellRegistration { cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    }
    self.settingsIconCellRegistration = settingsIconCellRegistration

    super.init(
      collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let model as SettingsCell.Model:
          let cell = collectionView.dequeueConfiguredReusableCell(using: settingsIconCellRegistration, for: indexPath, item: model)
          return cell
        default: return cellProvider?(collectionView, indexPath, itemIdentifier)
        }
      })
    
    collectionView.setCollectionViewLayout(TKCollectionLayout.layout(sectionLayout: { sectionIndex in
      return TKCollectionLayout.listSectionLayout(
        padding: NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        heightDimension: .estimated(76))
    }), animated: false)
    
    collectionView.contentInset.bottom = 16
  }
  
  func setSettingsSections(_ sections: [SettingsListSection]) {
    var snapshot = dataSource!.snapshot()
    snapshot.deleteAllItems()
    snapshot.appendSections(sections)
    for section in sections {
      snapshot.appendItems(section.items, toSection: section)
    }
    snapshot.reloadSections(sections)
    UIView.performWithoutAnimation {
      dataSource?.apply(snapshot, animatingDifferences: true)
    }
  }
}
