//
//  ActivityListCollectionLayoutConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 6.6.23..
//

import UIKit

struct ActivityListCollectionLayoutConfigurator {
  func getLayout(section: @escaping (_ sectionIndex: Int) -> ActivityListSection) -> UICollectionViewLayout {
    let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
      return createTransactionSection()
    }
    return layout
  }
}

private extension ActivityListCollectionLayoutConfigurator {
  func createTransactionSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .transactionSectionItemSize)
    let group = NSCollectionLayoutGroup.vertical(layoutSize: .transactionSectionGroupItemSize,
                                                 subitems: [item])
    group.contentInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)

    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 8
    section.contentInsets = .transactionSectionContentInsets
    
    let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(28))
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: ActivityListSectionHeaderView.reuseIdentifier,
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
    .init(top: 14, leading: ContentInsets.sideSpace, bottom: 30, trailing: ContentInsets.sideSpace)
  }
}
