import UIKit

struct WalletBalanceLayout {
  enum SupplementaryItem: String {
    case header = "WalletBalanceLayout.SupplementaryItem.header"
  }
  
  static func createLayout() -> UICollectionViewLayout {
    let header = createHeaderSupplementaryItem()
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.boundarySupplementaryItems = [header]
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: sectionProvider(),
      configuration: configuration
    )
    
    return layout
  }
  
  static func sectionProvider() -> UICollectionViewCompositionalLayoutSectionProvider {
    return { sectionIndex, environment in
      return nil
    }
  }
  
  static func createHeaderSupplementaryItem() -> NSCollectionLayoutBoundarySupplementaryItem {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(500)
    )
    
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: size,
      elementKind: SupplementaryItem.header.rawValue,
      alignment: .top
    )
    
    return header
  }
}
