import UIKit
import TKUIKit

final class SettingsRootCollectionController: TKCollectionController<SettingsSection, AnyHashable> {
  
  typealias SettingsIconCellRegistration = UICollectionView.CellRegistration<SettingsCell, SettingsCell.Model>
  
  private let settingsIconCellRegistration: SettingsIconCellRegistration
  
  init(collectionView: UICollectionView,
       headerViewProvider: (() -> UIView)? = nil, footerViewProvider: (() -> UIView)? = nil) {
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
        default: return nil
        }
      },
      headerViewProvider: headerViewProvider)
    
    collectionView.setCollectionViewLayout(TKCollectionLayout.layout(sectionLayout: { [weak self] sectionIndex in
      guard let self = self else { return nil }
      let section = dataSource.snapshot().sectionIdentifiers[sectionIndex]
      switch section {
//      case .wallet:
//        return TKCollectionLayout.listSectionLayout(
//          padding: NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
//          heightDimension: .absolute(76))
      case .settingsItems:
        return TKCollectionLayout.listSectionLayout(
          padding: NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
          heightDimension: .estimated(76))
      }
    }), animated: false)
    
    collectionView.contentInset.bottom = 16
  }
  
  func setSettingsSections(_ sections: [SettingsSection]) {
    var snapshot = dataSource!.snapshot()
    snapshot.deleteAllItems()
    snapshot.appendSections(sections)
    for section in sections {
      switch section {
//      case .wallet(let item):
//        snapshot.appendItems([item], toSection: section)
      case .settingsItems(let items):
        snapshot.appendItems(items, toSection: section)
      }
    }
    snapshot.reloadSections(sections)
    UIView.performWithoutAnimation {
      dataSource?.apply(snapshot, animatingDifferences: true)
    }
  }
}
