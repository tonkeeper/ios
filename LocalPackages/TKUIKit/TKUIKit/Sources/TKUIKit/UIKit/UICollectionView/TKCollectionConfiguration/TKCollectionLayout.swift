import UIKit

public struct TKCollectionLayout {
  
  let layout: UICollectionViewCompositionalLayout
  
  var sectionLayout: ((Int) -> NSCollectionLayoutSection)?
  
  public static func layout(sectionLayout: @escaping (Int) -> NSCollectionLayoutSection?) -> UICollectionViewLayout {
    let header = createHeaderSupplementaryItem()
    let footer = createFooterSupplementaryItem()
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.boundarySupplementaryItems = [header, footer]
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { sectionIndex, _ in
        sectionLayout(sectionIndex)
      }, configuration: configuration
    )
    
    return layout
  }

  static func createHeaderSupplementaryItem() -> NSCollectionLayoutBoundarySupplementaryItem {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: size,
      elementKind: TKCollectionSupplementaryItem.header.kind,
      alignment: .top
    )
    return header
  }
  
  static func createFooterSupplementaryItem() -> NSCollectionLayoutBoundarySupplementaryItem {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: size,
      elementKind: TKCollectionSupplementaryItem.footer.kind,
      alignment: .bottom
    )
    return header
  }
}

public extension TKCollectionLayout {
  static func listSectionLayout(padding: NSDirectionalEdgeInsets, heightDimension: NSCollectionLayoutDimension) -> NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: heightDimension
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: heightDimension
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = padding
    return section
  }
}
