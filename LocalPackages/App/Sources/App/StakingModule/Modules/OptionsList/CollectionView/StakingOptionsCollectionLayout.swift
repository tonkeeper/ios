import UIKit
import TKUIKit

extension String {
  static let stakingOptionSsectionHeaderElementKind = "StakingOptionSectionHeader"
}

enum StakingOptionsCollectionLayout {
  static var layout: UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      section: Self.sectionLayout,
      configuration: configuration
    )
    return layout
  }
  
  private static var sectionLayout: NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(.estimetedItemHeight)
    )
    
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(.estimetedItemHeight)
    )
    
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: groupSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .sectionInsets
    
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(.estimetedHeaderHeight)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: .stakingOptionSsectionHeaderElementKind,
      alignment: .top
    )
    header.contentInsets = .headerInsets
    section.boundarySupplementaryItems = [header]
    
    return section
  }
}

private extension NSDirectionalEdgeInsets {
  static let headerInsets: Self = .init(top: 0, leading: 2, bottom: 0, trailing: 0)
  static let sectionInsets: Self = .init(top: 0, leading: 16, bottom: 16, trailing: 16)
}

private extension CGFloat {
  static let estimetedItemHeight: Self = 76
  static let estimetedHeaderHeight: Self = 56
}
