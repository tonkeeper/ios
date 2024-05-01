import UIKit
import TKUIKit

final class SettingsCollectionController: NSObject {
  typealias ItemCell = GenericCollectionViewCell<AccessoryListItemView<TwoLinesListItemView>>
  typealias DataSource = UICollectionViewDiffableDataSource<SettingsListSection, SettingsListItem>
  
  var didSelectItem: ((MainListKeyItem) -> Void)?
  
  private let collectionView: UICollectionView
  private var dataSource: DataSource?
  
  var footerView: UIView? {
    didSet {
      collectionView.reloadData()
    }
  }
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init()
    setupCollectionView()
  }
  
  func setItems(_ items: [SettingsListSection]) {
    var snapshot = NSDiffableDataSourceSnapshot<SettingsListSection, SettingsListItem>()
    items.forEach {
      snapshot.appendSections([$0])
      snapshot.appendItems($0.items, toSection: $0)
    }
    dataSource?.apply(snapshot)
  }
}

private extension SettingsCollectionController {
  func setupCollectionView() {
    collectionView.register(
      ItemCell.self, 
      forCellWithReuseIdentifier: ItemCell.reuseIdentifier
    )
    collectionView.register(
      CollectionViewSupplementaryContainerView.self,
      forSupplementaryViewOfKind: CollectionElementKind.footer.rawValue, 
      withReuseIdentifier: CollectionViewSupplementaryContainerView.reuseIdentifier
    )
    collectionView.setCollectionViewLayout(SettingsCollectionLayout.layout(), animated: false)
    dataSource = createDataSource()
    collectionView.dataSource = dataSource
    collectionView.delegate = self
  }
  
  func createDataSource() -> DataSource {
    let dataSource = DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, itemIdentifier -> UICollectionViewCell? in
      guard let self = self else { return nil }
      return self.dequeueCell(collectionView: collectionView, indexPath: indexPath, itemIdentifier: itemIdentifier)
    }
    
    dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let self = self else { return nil }
      return dequeueSupplementaryView(
        collectionView: collectionView,
        kind: kind,
        indexPath: indexPath
      )
    }

    return dataSource
  }
  
  func dequeueSupplementaryView(collectionView: UICollectionView,
                                kind: String,
                                indexPath: IndexPath) -> UICollectionReusableView? {
    guard let kind = CollectionElementKind(rawValue: kind) else { return nil }
    switch kind {
    case .footer:
      return dequeueFooter(
        collectionView: collectionView,
        kind: kind,
        indexPath: indexPath
      )
    }
  }
  
  func dequeueFooter(collectionView: UICollectionView, kind: CollectionElementKind, indexPath: IndexPath) -> UICollectionReusableView {
    let container = collectionView.dequeueReusableSupplementaryView(
      ofKind: kind.rawValue,
      withReuseIdentifier: CollectionViewSupplementaryContainerView.reuseIdentifier,
      for: indexPath
    )
    (container as? CollectionViewSupplementaryContainerView)?.setContentView(footerView)
    return container
  }
  
  func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: SettingsListItem) -> UICollectionViewCell? {
    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ItemCell.reuseIdentifier, for: indexPath) as? ItemCell else {
      return nil
    }
    cell.configure(model: itemIdentifier.model)
    cell.isFirstCellInSection = { ip in ip.item == 0 }
    cell.isLastCellInSection = { [weak collectionView = collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
    return cell
  }
}

extension SettingsCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let snapshot = dataSource?.snapshot() else { return }
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.row]
    item.action?()
  }
}
