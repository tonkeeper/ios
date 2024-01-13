import UIKit
import TKUIKit

final class WalletBalanceCollectionController: NSObject {
  typealias DataSource = UICollectionViewDiffableDataSource<WalletBalanceSection, String>
  typealias HeaderSupplementaryRegistration = UICollectionView.SupplementaryRegistration<CollectionViewSupplementaryContainerView>
  
  private let collectionView: UICollectionView
  private let headerViewProvider: () -> UIView

  private var dataSource: DataSource?
  private let headerRegistration = HeaderSupplementaryRegistration(
    elementKind: WalletBalanceLayout.SupplementaryItem.header.rawValue) { supplementaryView, elementKind, indexPath in
      
    }
  
  init(collectionView: UICollectionView,
       headerViewProvider: @escaping () -> UIView) {
    self.collectionView = collectionView
    self.headerViewProvider = headerViewProvider
    super.init()
    setupCollectionView()
    dataSource = createDataSource(collectionView: collectionView)
  }
}

private extension WalletBalanceCollectionController {
  func setupCollectionView() {
    collectionView.setCollectionViewLayout(
      WalletBalanceLayout.createLayout(), 
      animated: false
    )
  }
  
  func createDataSource(collectionView: UICollectionView) -> DataSource {
    let dataSource = DataSource(
      collectionView: collectionView) { collectionView, indexPath, itemIdentifier in
        return nil
      }
    
    dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath -> UICollectionReusableView? in
      self?.createSupplementaryView(collectionView: collectionView, kind: kind, indexPath: indexPath)
    }
    
    return dataSource
  }
  
  func createSupplementaryView(collectionView: UICollectionView, 
                               kind: String,
                               indexPath: IndexPath) -> UICollectionReusableView? {
    switch WalletBalanceLayout.SupplementaryItem(rawValue: kind) {
    case .header:
      let headerSupplementaryView = collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
      headerSupplementaryView.setContentView(headerViewProvider())
      return headerSupplementaryView
    case .none:
      return nil
    }
  }
}
