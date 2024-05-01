import UIKit
import TKUIKit

final class MainCollectionController: NSObject {
  typealias KeyItemCell = GenericCollectionViewCell<AccessoryListItemView<TwoLinesListItemView>>
  typealias DataSource = UICollectionViewDiffableDataSource<String, MainListKeyItem>
  
  var didSelectItem: ((IndexPath) -> Void)?
  
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
  
  func setItems(_ items: [MainListKeyItem]) {
    var snapshot = NSDiffableDataSourceSnapshot<String, MainListKeyItem>()
    snapshot.appendSections([""])
    snapshot.appendItems(items)
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(items)
    } else {
      snapshot.reloadItems(items)
    }
    dataSource?.apply(snapshot)
  }
  
  func addItem(_ item: MainListKeyItem) {
    guard var snapshot = dataSource?.snapshot() else { return }
    snapshot.appendItems([item])
    dataSource?.apply(snapshot)
  }
}

private extension MainCollectionController {
  func setupCollectionView() {
    collectionView.register(
      CollectionViewSupplementaryContainerView.self,
      forSupplementaryViewOfKind: CollectionViewSupplementaryContainerView.reuseIdentifier,
      withReuseIdentifier: CollectionViewSupplementaryContainerView.reuseIdentifier
    )
    collectionView.register(KeyItemCell.self, forCellWithReuseIdentifier: "Cell")
    collectionView.setCollectionViewLayout(MainCollectionLayout.layout(), animated: false)
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
  
  func dequeueKeyItemCell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: MainListKeyItem) -> UICollectionViewCell? {
    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as? KeyItemCell else {
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

extension MainCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    didSelectItem?(indexPath)
  }
}

extension UICollectionView {
  func isFirstItemInSection(indexPath: IndexPath) -> Bool {
    indexPath.row == 0
  }
  func isLastItemInSection(indexPath: IndexPath) -> Bool {
    indexPath.item == numberOfItems(inSection: indexPath.section) - 1
  }
}
