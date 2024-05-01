import UIKit
import TKUIKit

final class KeyDetailsCollectionController: NSObject {
  typealias KeyItemCell = GenericCollectionViewCell<AccessoryListItemView<TwoLinesListItemView>>
  typealias DataSource = UICollectionViewDiffableDataSource<KeyDetailsListSection, KeyDetailsListKeyItem>
  
  var didSelectItem: ((IndexPath) -> Void)?
  
  var qrCodeImage: (() -> UIImage)?
  
  private let collectionView: UICollectionView
  private var dataSource: DataSource?
  
  var headerView: UIView? {
    didSet {
      collectionView.reloadData()
    }
  }
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init()
    setupCollectionView()
  }
  
  func setItems(_ items: [KeyDetailsListSection]) {
    var snapshot = NSDiffableDataSourceSnapshot<KeyDetailsListSection, KeyDetailsListKeyItem>()
    items.forEach { section in
      snapshot.appendSections([section])
      snapshot.appendItems(section.items, toSection: section)
    }

    dataSource?.apply(snapshot)
  }
}

private extension KeyDetailsCollectionController {
  func setupCollectionView() {
    collectionView.register(
      CollectionViewSupplementaryContainerView.self,
      forSupplementaryViewOfKind: CollectionViewSupplementaryContainerView.reuseIdentifier,
      withReuseIdentifier: CollectionViewSupplementaryContainerView.reuseIdentifier
    )
    collectionView.register(
      GenericCollectionViewCell<AccessoryListItemView<TwoLinesListItemView>>.self,
      forCellWithReuseIdentifier: GenericCollectionViewCell<AccessoryListItemView<TwoLinesListItemView>>.reuseIdentifier
    )
    collectionView.register(
      GenericCollectionViewCell<TwoLinesListItemView>.self,
      forCellWithReuseIdentifier: GenericCollectionViewCell<TwoLinesListItemView>.reuseIdentifier
    )
    collectionView.register(
      GenericCollectionViewCell<KeyDetailsQRCodeItemView>.self,
      forCellWithReuseIdentifier: GenericCollectionViewCell<KeyDetailsQRCodeItemView>.reuseIdentifier
    )
    
    let layout = KeyDetailsCollectionLayout.layout { [weak self] sectionIndex in
      self?.dataSource?.snapshot().sectionIdentifiers[sectionIndex]
    }
    
    collectionView.setCollectionViewLayout(layout, animated: false)
    dataSource = createDataSource()
    collectionView.dataSource = dataSource
    collectionView.delegate = self
  }
  
  func createDataSource() -> DataSource {
    let dataSource = DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, itemIdentifier -> UICollectionViewCell? in
      guard let self = self else { return nil }
      return self.dequeueKeyItemCell(collectionView: collectionView, indexPath: indexPath, itemIdentifier: itemIdentifier)
    }

    dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let self = self else { return nil }
      return dequeueSupplementaryView(collectionView: collectionView, kind: kind, indexPath: indexPath)
    }
      
      return dataSource
  }
  func dequeueSupplementaryView(collectionView: UICollectionView,
                                kind: String,
                                indexPath: IndexPath) -> UICollectionReusableView? {
    if kind == CollectionViewSupplementaryContainerView.reuseIdentifier {
      return createHeaderView(collectionView: collectionView, kind: kind, indexPath: indexPath)
    }
    return nil
  }
  
  func createHeaderView(collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView {
    let headerContainer = collectionView.dequeueReusableSupplementaryView(
      ofKind: kind,
      withReuseIdentifier: CollectionViewSupplementaryContainerView.reuseIdentifier,
      for: indexPath)
    (headerContainer as? CollectionViewSupplementaryContainerView)?.setContentView(headerView)
    return headerContainer
  }
  
  func dequeueKeyItemCell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: KeyDetailsListKeyItem) -> UICollectionViewCell? {
    switch itemIdentifier.model {
    case let model as AccessoryListItemView<TwoLinesListItemView>.Model:
      return getAccessoryTwoLinesListItemViewCell(
        collectionView: collectionView,
        indexPath: indexPath,
        model: model
      )
    case let model as TwoLinesListItemView.Model:
      return getTwoLinesListItemViewCell(
        collectionView: collectionView,
        indexPath: indexPath,
        model: model
      )
    case let model as KeyDetailsQRCodeItemView.Model:
      return getQRCodeCell(
        collectionView: collectionView,
        indexPath: indexPath,
        model: model)
    default:
      return nil
    }
  }
  
  func getTwoLinesListItemViewCell(collectionView: UICollectionView,
                                   indexPath: IndexPath,
                                   model: TwoLinesListItemView.Model) -> UICollectionViewCell? {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: GenericCollectionViewCell<TwoLinesListItemView>.reuseIdentifier,
      for: indexPath
    ) as? GenericCollectionViewCell<TwoLinesListItemView> else {
      return nil
    }
    cell.configure(model: model)
    cell.isFirstCellInSection = { ip in ip.item == 0 }
    cell.isLastCellInSection = { [weak collectionView = collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
    return cell
  }
  
  func getAccessoryTwoLinesListItemViewCell(collectionView: UICollectionView,
                                            indexPath: IndexPath,
                                            model: AccessoryListItemView<TwoLinesListItemView>.Model) -> UICollectionViewCell? {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: GenericCollectionViewCell<AccessoryListItemView<TwoLinesListItemView>>.reuseIdentifier,
      for: indexPath
    ) as? GenericCollectionViewCell<AccessoryListItemView<TwoLinesListItemView>> else {
      return nil
    }
    cell.configure(model: model)
    cell.isFirstCellInSection = { ip in ip.item == 0 }
    cell.isLastCellInSection = { [weak collectionView = collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
    return cell
  }
  
  func getQRCodeCell(collectionView: UICollectionView,
                     indexPath: IndexPath,
                     model: KeyDetailsQRCodeItemView.Model) -> UICollectionViewCell? {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: GenericCollectionViewCell<KeyDetailsQRCodeItemView>.reuseIdentifier,
      for: indexPath
    ) as? GenericCollectionViewCell<KeyDetailsQRCodeItemView> else {
      return nil
    }
    cell.configure(model: model)
    cell.isFirstCellInSection = { ip in ip.item == 0 }
    cell.isLastCellInSection = { [weak collectionView = collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
    return cell
  }
}

extension KeyDetailsCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let dataSource = dataSource else { return }
    let sectionIdentifier = dataSource.snapshot().sectionIdentifiers[indexPath.section]
    let itemIdentifier = dataSource.snapshot().itemIdentifiers(inSection: sectionIdentifier)[indexPath.item]
    itemIdentifier.action?()
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
    guard let dataSource = dataSource else { return false }
    let sectionIdentifier = dataSource.snapshot().sectionIdentifiers[indexPath.section]
    let itemIdentifier = dataSource.snapshot().itemIdentifiers(inSection: sectionIdentifier)[indexPath.item]
    return itemIdentifier.isHighlightable
  }
}
