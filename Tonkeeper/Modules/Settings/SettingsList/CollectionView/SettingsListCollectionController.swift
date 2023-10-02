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
//    let layout = collectionLayoutConfigurator.getLayout { [weak self] sectionIndex in
//      guard let self = self, let snapshot = self.dataSource?.snapshot() else { return nil }
//      return snapshot.sectionIdentifiers[sectionIndex]
//    }
//    collectionView.delegate = self
    collectionView.setCollectionViewLayout(collectionLayoutConfigurator.layout, animated: false)
    
    collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
//    collectionView.register(UITableViewCell.self, forCellWithReuseIdentifier: "Cell")
    collectionView.dataSource = self
//    collectionView.register(
//      ActivityListCompositionTransactionCell.self,
//      forCellWithReuseIdentifier: ActivityListCompositionTransactionCell.reuseIdentifier)
//    collectionView.register(
//      ActivityListShimmerCell.self,
//      forCellWithReuseIdentifier: ActivityListShimmerCell.reuseIdentifier)
//    collectionView.register(
//      ActivityListSectionHeaderView.self,
//      forSupplementaryViewOfKind: ActivityListSectionHeaderView.reuseIdentifier,
//      withReuseIdentifier: ActivityListSectionHeaderView.reuseIdentifier)
//    collectionView.register(
//      ActivityListFooterView.self,
//      forSupplementaryViewOfKind: ActivityListFooterView.reuseIdentifier,
//      withReuseIdentifier: ActivityListFooterView.reuseIdentifier)
//    collectionView.register(
//      ActivityListShimmerSectionHeaderView.self,
//      forSupplementaryViewOfKind: ActivityListShimmerSectionHeaderView.reuseIdentifier,
//      withReuseIdentifier: ActivityListShimmerSectionHeaderView.reuseIdentifier)
//    collectionView.register(
//      ActivityListHeaderContainer.self,
//      forSupplementaryViewOfKind: ActivityListHeaderContainer.reuseIdentifier,
//      withReuseIdentifier: ActivityListHeaderContainer.reuseIdentifier
//    )
//    dataSource = createDataSource(collectionView: collectionView)
  }
}

extension SettingsListCollectionController: UICollectionViewDataSource {
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    sections.count
  }
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    sections[section].items.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let item = sections[indexPath.section].items[indexPath.row]
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
    cell.contentView.backgroundColor = .red
    let l = UILabel()
    l.textColor = .white
    l.text = item.title
    cell.contentView.addSubview(l)
    l.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      l.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
      l.leftAnchor.constraint(equalTo: cell.contentView.leftAnchor),
      l.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
      l.rightAnchor.constraint(equalTo: cell.contentView.rightAnchor)
    ])
    
    
    return cell
  }
}
