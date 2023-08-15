//
//  ActivityListCollectionLayoutConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 6.6.23..
//

import UIKit

struct ActivityListCollectionLayoutConfigurator {
  func getLayout(section: @escaping (_ sectionIndex: Int) -> ActivityListSection?) -> UICollectionViewLayout {
    let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
      guard let sectionItem = section(sectionIndex) else { return nil }
      return createSection(sectionItem)
    }

    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(100)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: ActivityListHeaderContainer.reuseIdentifier,
      alignment: .top
    )
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.boundarySupplementaryItems = [header]
    layout.configuration = configuration
    
    return layout
  }
}

private extension ActivityListCollectionLayoutConfigurator {
  func createSection(_ section: ActivityListSection) -> NSCollectionLayoutSection {
    switch section {
    case .events: return createTransactionSection()
    case .shimmer: return createShimmerSection()
    case .pagination: return createPaginationSection()
    }
  }
  
  func createPaginationSection() -> NSCollectionLayoutSection {
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
      elementKind: ActivityListFooterView.reuseIdentifier,
      alignment: .bottom
    )
    section.boundarySupplementaryItems = [footer]
    
    return section
  }
  
  func createTransactionSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .transactionSectionItemSize)
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: .transactionSectionGroupItemSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 8
    section.contentInsets = .transactionSectionContentInsets
    
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(56)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: ActivityListSectionHeaderView.reuseIdentifier,
      alignment: .top
    )
    section.boundarySupplementaryItems = [header]
    
    return section
  }
  
  func createShimmerSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .transactionSectionItemSize)
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: .transactionSectionGroupItemSize,
      subitems: [item]
    )

    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 8
    section.contentInsets = .transactionSectionContentInsets
    
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(56)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: ActivityListShimmerSectionHeaderView.reuseIdentifier,
      alignment: .top
    )
    section.boundarySupplementaryItems = [header]
    
    return section
  }
}

private extension NSCollectionLayoutSize {
  static var transactionSectionItemSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(76))
  }
  
  static var transactionSectionGroupItemSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(76))
  }
}

private extension NSDirectionalEdgeInsets {
  static var transactionSectionContentInsets: NSDirectionalEdgeInsets {
    .init(top: 0,
          leading: ContentInsets.sideSpace,
          bottom: 16, 
          trailing: ContentInsets.sideSpace)
  }
}
