import UIKit
import TKUIKit

struct KeyDetailsCollectionLayout {
  static func layout(sectionProvider: @escaping (_ sectionIndex: Int) -> KeyDetailsListSection?) -> UICollectionViewLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical

    let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, environment in
      guard let section = sectionProvider(sectionIndex) else { return nil }
      return createLayout(for: section)
    }, configuration: configuration)
    
    return layout
  }
  
  private static func createLayout(for section: KeyDetailsListSection) -> NSCollectionLayoutSection {
    switch section {
    case .anotherDeviceExport:
      return createAnotherDeviceExportSectionLayout()
    case .sameDeviceExport:
      return createSameDeviceExportSectionLayout()
    case .webExport:
      return createWebExportSectionLayout()
    case .actions:
      return createActionsSectionLayout()
    }
  }
  
  private static func createAnotherDeviceExportSectionLayout() -> NSCollectionLayoutSection {
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
    section.contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 16, bottom: 16, trailing: 16)
    return section
  }
  
  private static func createSameDeviceExportSectionLayout() -> NSCollectionLayoutSection {
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
    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
    return section
  }
  
  private static func createWebExportSectionLayout() -> NSCollectionLayoutSection {
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
  
  private static func createActionsSectionLayout() -> NSCollectionLayoutSection {
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
    section.contentInsets = NSDirectionalEdgeInsets(top: 48, leading: 16, bottom: 16, trailing: 16)
    return section
  }
}
