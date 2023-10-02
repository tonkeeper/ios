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
      layoutSize: NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(56)
      )
    )
    
    let group = NSCollectionLayoutGroup.vertical(
      layoutSize: NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(56)
      ),
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    
    let layout = UICollectionViewCompositionalLayout(section: section)
    
    return layout
  }
}
