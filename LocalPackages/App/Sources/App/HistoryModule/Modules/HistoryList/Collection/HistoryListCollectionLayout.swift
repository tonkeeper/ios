import UIKit

struct HistoryListCollectionLayout {
  static func layout(sectionProvider: @escaping (_ sectionIndex: Int) -> HistoryListSection?) -> UICollectionViewLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    return UICollectionViewCompositionalLayout(
      sectionProvider: { sectionIndex, _ in
        guard let section = sectionProvider(sectionIndex) else { return nil }
        return createSectionLayout(section: section)
      },
      configuration: configuration
    )
  }
  
  static func createSectionLayout(section: HistoryListSection) -> NSCollectionLayoutSection {
    switch section {
    case .events:
      createEventsSection()
    case .pagination:
      createPaginationSection()
    }
  }
  
  static func createEventsSection() -> NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: groupSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 8
    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
    
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(56)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: HistoryListSupplementaryItem.sectionHeader.rawValue,
      alignment: .top
    )
    section.boundarySupplementaryItems = [header]
    
    return section
  }
  
  static func createPaginationSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                                        heightDimension: .absolute(10)))
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(10)),
      subitems: [item]
    )
    let section = NSCollectionLayoutSection(group: group)
    let footerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(40)
    )
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: HistoryListSupplementaryItem.footer.rawValue,
      alignment: .bottom
    )
    section.boundarySupplementaryItems = [footer]
    
    return section
  }
}
