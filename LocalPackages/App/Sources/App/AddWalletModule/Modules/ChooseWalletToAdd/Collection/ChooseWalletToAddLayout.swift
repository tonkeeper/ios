import UIKit
import TKUIKit

public struct ChooseWalletToAddLayout {
  public enum SupplementaryItem: String {
    case header = "TKCollectionLayout.SupplementaryItem.Header"
  }
  
  public static func createLayout() -> UICollectionViewLayout {
    let header = createHeaderSupplementaryItem()
    header.pinToVisibleBounds = true
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.boundarySupplementaryItems = [header]
    
    let section = createListSectionLayout()
    
    let layout = UICollectionViewCompositionalLayout(
      section: section, 
      configuration: configuration
    )
    
    return layout
  }
  
  static func createListSectionLayout() -> NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
    return section
  }
  
  static func createHeaderSupplementaryItem() -> NSCollectionLayoutBoundarySupplementaryItem {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: size,
      elementKind: TKCollectionSupplementaryItem.header.rawValue,
      alignment: .top
    )
    return header
  }
}
