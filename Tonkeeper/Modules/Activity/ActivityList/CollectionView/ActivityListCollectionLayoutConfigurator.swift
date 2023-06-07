//
//  ActivityListCollectionLayoutConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 6.6.23..
//

import UIKit

struct ActivityListCollectionLayoutConfigurator {
  func getLayout() -> UICollectionViewLayout {
    let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
      return self.createLayoutSection()
    }
    layout.register(TokensListTokensSectionBackgroundView.self,
                    forDecorationViewOfKind: .transactionSectionBackgroundElementKid)
    return layout
  }
}

private extension ActivityListCollectionLayoutConfigurator {
  func createLayoutSection() -> NSCollectionLayoutSection {
    createTransactionSection()
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

private extension String {
  static let transactionSectionBackgroundElementKid = "transactionSectionBackground"
}

private extension NSDirectionalEdgeInsets {
  static var transactionSectionContentInsets: NSDirectionalEdgeInsets {
    .init(top: 0, leading: ContentInsets.sideSpace, bottom: 10, trailing: ContentInsets.sideSpace)
  }
  
  static var collectiblesSectionContentInsets: NSDirectionalEdgeInsets {
    .init(top: 0, leading: ContentInsets.sideSpace, bottom: 10, trailing: ContentInsets.sideSpace)
  }
}
