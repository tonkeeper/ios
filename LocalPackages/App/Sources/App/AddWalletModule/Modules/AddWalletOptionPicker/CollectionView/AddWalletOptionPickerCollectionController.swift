import UIKit
import TKUIKit

final class AddWalletOptionPickerCollectionController: TKCollectionController<AddWalletOptionPickerSection, AnyHashable> {
  
  typealias OptionCellRegistration = UICollectionView.CellRegistration<AddWalletOptionPickerCell, AddWalletOptionPickerCell.Model>
  
  private let optionCellRegistration: OptionCellRegistration
  
  init(collectionView: UICollectionView,
       headerViewProvider: (() -> UIView)? = nil, footerViewProvider: (() -> UIView)? = nil) {
    let optionCellRegistration = OptionCellRegistration { cell, indexPath, itemIdentifier in
      cell.configure(model: itemIdentifier)
    }
    self.optionCellRegistration = optionCellRegistration
    
    super.init(
      collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let model as AddWalletOptionPickerCell.Model:
          let cell = collectionView.dequeueConfiguredReusableCell(using: optionCellRegistration, for: indexPath, item: model)
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
      case .options:
        return TKCollectionLayout.listSectionLayout(
          padding: NSDirectionalEdgeInsets(top: 0, leading: 32, bottom: 16, trailing: 32),
          heightDimension: .estimated(76))
      }
    }), animated: false)
    
    collectionView.contentInset.bottom = 16
  }
  
  func setOptionSections(_ sections: [AddWalletOptionPickerSection]) {
    var snapshot = dataSource.snapshot()
    snapshot.deleteAllItems()
    for section in sections {
      switch section {
      case .options(let item):
        snapshot.appendSections([section])
        snapshot.appendItems([item], toSection: section)
      }
    }
    dataSource.apply(snapshot, animatingDifferences: false)
  }
}
