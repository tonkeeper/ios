//
//  SettingsListCollectionLayoutConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit

struct SettingsListCollectionLayoutConfigurator {
  var layout: UICollectionViewLayout {
    
    let item = NSCollectionLayoutItem(
      layoutSize: .itemSize
    )
    
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: .groupSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    let background = NSCollectionLayoutDecorationItem.background(elementKind: .sectionBackgroundIdentifier)
    background.contentInsets = .sectionContentInsets
    section.contentInsets = .sectionContentInsets
    section.decorationItems = [background]
    
    let layout = UICollectionViewCompositionalLayout(section: section)
    layout.register(TokensListTokensSectionBackgroundView.self,
                    forDecorationViewOfKind: .sectionBackgroundIdentifier)
    
    let footerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(100)
    )
    
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: CollectionViewReusableContainerView.reuseIdentifier,
      alignment: .bottom
    )
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.interSectionSpacing = .interSectionSpacing
    configuration.boundarySupplementaryItems = [footer]
    layout.configuration = configuration

    return layout
  }
}

private extension String {
  static let sectionBackgroundIdentifier = "sectionBackground"
}

private extension CGFloat {
  static let interSectionSpacing: CGFloat = 32
}

private extension NSDirectionalEdgeInsets {
  static let sectionContentInsets = NSDirectionalEdgeInsets(
    top: 0,
    leading: ContentInsets.sideSpace,
    bottom: 0,
    trailing: ContentInsets.sideSpace
  )
}

private extension NSCollectionLayoutSize {
  static let itemSize = NSCollectionLayoutSize(
    widthDimension: .fractionalWidth(1.0),
    heightDimension: .absolute(56)
  )
  
  static let groupSize = NSCollectionLayoutSize(
    widthDimension: .fractionalWidth(1.0),
    heightDimension: .absolute(56)
  )
}
