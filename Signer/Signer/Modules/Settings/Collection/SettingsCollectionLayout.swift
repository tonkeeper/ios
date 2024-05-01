import UIKit
import TKUIKit

struct SettingsCollectionLayout {
  static func layout() -> UICollectionViewLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.interSectionSpacing = 16
    
    let footerSize = NSCollectionLayoutSize(
      widthDimension: NSCollectionLayoutDimension.fractionalWidth(1.0),
      heightDimension: NSCollectionLayoutDimension.estimated(0)
    )
    
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: CollectionElementKind.footer.rawValue,
      alignment: .bottom
    )
    configuration.boundarySupplementaryItems = [footer]
    
    return UICollectionViewCompositionalLayout(section: createItemsSection(), configuration: configuration)
  }
  
  private static func createItemsSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(50))
    )
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(50)),
      subitems: [item]
    )
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    return section
  }
}

enum CollectionElementKind: String {
  case footer = "footerElementKind"
}
