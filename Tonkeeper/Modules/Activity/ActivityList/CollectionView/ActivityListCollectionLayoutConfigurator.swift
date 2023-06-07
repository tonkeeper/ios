//
//  ActivityListCollectionLayoutConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 6.6.23..
//

import UIKit

struct ActivityListCollectionLayoutConfigurator {
  func getLayout(section: @escaping (_ sectionIndex: Int) -> ActivityListSection.SectionType) -> UICollectionViewLayout {
    let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
      let sectionType = section(sectionIndex)
      return self.createLayoutSection(type: sectionType)
    }
    layout.register(TokensListTokensSectionBackgroundView.self,
                    forDecorationViewOfKind: .transactionSectionBackgroundElementKid)
    return layout
  }
}

private extension ActivityListCollectionLayoutConfigurator {
  func createLayoutSection(type: ActivityListSection.SectionType) -> NSCollectionLayoutSection {
    switch type {
    case .transaction:
      return createTransactionSection()
    case .date:
      return createDateSection()
    }
  }
  
  func createTransactionSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .transactionSectionItemSize)
    let group = NSCollectionLayoutGroup.vertical(layoutSize: .transactionSectionGroupItemSize,
                                                 subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    let background = NSCollectionLayoutDecorationItem.background(
      elementKind: .transactionSectionBackgroundElementKid
    )
    background.contentInsets = .transactionSectionContentInsets
    section.decorationItems = [background]
    section.contentInsets = .transactionSectionContentInsets
    return section
  }
  
  func createDateSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .dateSectionItemSize)
    let group = NSCollectionLayoutGroup.vertical(layoutSize: .dateSectionGroupSize,
                                                 subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .dateSectionContentInsets
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
  
  static var dateSectionItemSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(28))
  }
  
  static var dateSectionGroupSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(28))
  }
}

private extension String {
  static let transactionSectionBackgroundElementKid = "transactionSectionBackground"
}

private extension NSDirectionalEdgeInsets {
  static var transactionSectionContentInsets: NSDirectionalEdgeInsets {
    .init(top: 0, leading: ContentInsets.sideSpace, bottom: 10, trailing: ContentInsets.sideSpace)
  }
  
  static var dateSectionContentInsets: NSDirectionalEdgeInsets {
    .init(top: 14, leading: ContentInsets.sideSpace, bottom: 14, trailing: ContentInsets.sideSpace)
  }
}
