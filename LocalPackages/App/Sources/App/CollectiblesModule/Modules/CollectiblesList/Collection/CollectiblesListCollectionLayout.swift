import UIKit

struct CollectiblesListCollectionLayout {
  static func layout() -> UICollectionViewLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      section: createCollectiblesSection(),
      configuration: configuration
    )
    return layout
  }
  
  static func createCollectiblesSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(
      layoutSize: NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1/3),
        heightDimension: .absolute(166)
      )
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1),
        heightDimension: .absolute(166)
      ),
      subitem: item,
      count: 3
    )
    group.interItemSpacing = .fixed(8)
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 0,
      trailing: 16
    )
    section.interGroupSpacing = 8
    return section
  }
}
