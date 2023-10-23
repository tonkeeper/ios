//
//  TokensListCollectionLayoutConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 26.5.23..
//

import UIKit

struct TokensListCollectionLayoutConfigurator {
  
  func getLayout(section: @escaping (_ sectionIndex: Int) -> TokensListSection.SectionType) -> UICollectionViewLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.interSectionSpacing = 32
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, environment in
      let sectionType = section(sectionIndex)
      return self.createLayoutSection(type: sectionType, environment: environment)
    }, configuration: configuration)
    layout.register(TokensListTokensSectionBackgroundView.self,
                    forDecorationViewOfKind: .tokensSectionBackgroundElementKid)
    return layout
  }
}

private extension TokensListCollectionLayoutConfigurator {
  func createLayoutSection(type: TokensListSection.SectionType,
                           environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    switch type {
    case .token:
      return createTokensSection()
    case .application:
      return createTokensSection()
    case .collectibles:
      return createCollectiblesSection()
    }
  }
  
  func createTokensSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .tokensSectionItemSize)
    let group = NSCollectionLayoutGroup.vertical(layoutSize: .tokensSectionGroupSize,
                                                 subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .tokensSectionContentInsets
    let background = NSCollectionLayoutDecorationItem.background(elementKind: .tokensSectionBackgroundElementKid)
    background.contentInsets = .tokensSectionContentInsets
    section.decorationItems = [background]
    return section
  }
  
  func createCollectiblesSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .collectiblesSectionItemSize)
    
    let group: NSCollectionLayoutGroup
    if #available(iOS 16.0, *) {
      group = NSCollectionLayoutGroup.horizontal(
        layoutSize: .collectiblesSectionGroupSize,
        repeatingSubitem: item,
        count: 3)
    } else {
      group = NSCollectionLayoutGroup.horizontal(
        layoutSize: .collectiblesSectionGroupSize,
        subitem: item,
        count: 3)
    }
    group.interItemSpacing = .collectiblesSectionInterItemSpacing
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .collectiblesSectionContentInsets
    section.interGroupSpacing = .collectiblesSectionInterGroupSpacing
    return section
  }
}

private extension NSCollectionLayoutSize {
  static var tokensSectionItemSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1),
          heightDimension: .absolute(76))
  }
  
  static var tokensSectionGroupSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(0))
  }
  
  static var collectiblesSectionItemSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1/3),
          heightDimension: .estimated(166))
  }
  
  static var collectiblesSectionGroupSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(0))
  }
}

private extension NSDirectionalEdgeInsets {
  static var tokensSectionContentInsets: NSDirectionalEdgeInsets {
    .init(top: 0, leading: 16, bottom: 0, trailing: 16)
  }
  
  static var collectiblesSectionContentInsets: NSDirectionalEdgeInsets {
    .init(top: 0, leading: 16, bottom: 0, trailing: 16)
  }
}

private extension NSCollectionLayoutSpacing {
  static var collectiblesSectionInterItemSpacing: NSCollectionLayoutSpacing {
    .fixed(8)
  }
}

private extension CGFloat {
  static let collectiblesSectionInterGroupSpacing: CGFloat = 8
  static let interSectionSpacing: CGFloat = 32
}

private extension String {
  static let tokensSectionBackgroundElementKid = "tokenSectionBackground"
}
