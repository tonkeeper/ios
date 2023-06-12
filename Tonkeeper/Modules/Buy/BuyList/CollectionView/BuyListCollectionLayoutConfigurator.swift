//
//  BuyListCollectionLayoutConfigurator.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import UIKit

struct BuyListCollectionLayoutConfigurator {
  func getLayout(section: @escaping (_ sectionIndex: Int) -> BuyListSection.SectionType) -> UICollectionViewLayout {
    let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
      let sectionType = section(sectionIndex)
      return self.createLayoutSection(type: sectionType)
    }
    layout.register(TokensListTokensSectionBackgroundView.self,
                    forDecorationViewOfKind: .servicesSectionBackgroundElementKid)
    return layout
  }
}

private extension BuyListCollectionLayoutConfigurator {
  func createLayoutSection(type: BuyListSection.SectionType) -> NSCollectionLayoutSection {
    switch type {
    case .services:
      return createServicesSection()
    case .button:
      return createButtonSection()
    }
  }
  
  func createServicesSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .servicesSectionItemSize)
    let group = NSCollectionLayoutGroup.vertical(layoutSize: .servicesSectionGroupItemSize,
                                                 subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    let background = NSCollectionLayoutDecorationItem.background(
      elementKind: .servicesSectionBackgroundElementKid
    )
    background.contentInsets = .servicesSectionContentInsets
    section.decorationItems = [background]
    section.contentInsets = .servicesSectionContentInsets
    return section
  }
  
  func createButtonSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .buttonSectionItemSize)
    let group = NSCollectionLayoutGroup.vertical(layoutSize: .buttonSectionGroupSize,
                                                 subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .buttonSectionContentInsets
    return section
  }
}

private extension NSCollectionLayoutSize {
  static var servicesSectionItemSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(76))
  }
  
  static var servicesSectionGroupItemSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(76))
  }
  
  static var buttonSectionItemSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(36))
  }
  
  static var buttonSectionGroupSize: NSCollectionLayoutSize {
    .init(widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(36))
  }
}

private extension String {
  static let servicesSectionBackgroundElementKid = "servicesSectionBackground"
}

private extension NSDirectionalEdgeInsets {
  static var servicesSectionContentInsets: NSDirectionalEdgeInsets {
    .init(top: 0, leading: ContentInsets.sideSpace, bottom: ContentInsets.sideSpace, trailing: ContentInsets.sideSpace)
  }
  
  static var buttonSectionContentInsets: NSDirectionalEdgeInsets {
    .init(top: 0, leading: ContentInsets.sideSpace, bottom: 32, trailing: ContentInsets.sideSpace)
  }
}

