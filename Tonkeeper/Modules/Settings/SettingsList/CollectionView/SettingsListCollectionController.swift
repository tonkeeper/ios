//
//  SettingsListCollectionController.swift
//  Tonkeeper
//
//  Created by Grigory on 2.10.23..
//

import UIKit

final class SettingsListCollectionController: NSObject {
  private weak var collectionView: UICollectionView?
  
  private let collectionLayoutConfigurator = SettingsListCollectionLayoutConfigurator()
  
  var sections = [SettingsListSection]()
  
  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init()
    setupCollectionView()
  }
}

private extension SettingsListCollectionController {
  func setupCollectionView() {
    guard let collectionView = collectionView else { return }
    collectionView.setCollectionViewLayout(collectionLayoutConfigurator.layout, animated: false)
    collectionView.register(
      SettingsListItemCollectionViewCell.self,
      forCellWithReuseIdentifier: SettingsListItemCollectionViewCell.reuseIdentifier
    )
    collectionView.dataSource = self
    collectionView.delegate = self
  }
}

// MARK: UICollectionViewDataSource

extension SettingsListCollectionController: UICollectionViewDataSource {
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    sections.count
  }
  
  func collectionView(_ collectionView: UICollectionView, 
                      numberOfItemsInSection section: Int) -> Int {
    sections[section].items.count
  }
  
  func collectionView(_ collectionView: UICollectionView, 
                      cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: SettingsListItemCollectionViewCell.reuseIdentifier,
      for: indexPath) as? SettingsListItemCollectionViewCell else { return UICollectionViewCell() }
    
    let item = sections[indexPath.section].items[indexPath.row]
    cell.configure(model: .init(title: item.title))
    cell.isFirstCell = indexPath.item == 0
    cell.isLastCell = indexPath.item == sections[indexPath.section].items.count - 1
    return cell
  }
}

// MARK: UICollectionViewDelegate

extension SettingsListCollectionController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    collectionView.deselectItem(at: indexPath, animated: true)
  }
}

