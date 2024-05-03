import UIKit
import TKUIKit

final class SettingsViewController: GenericViewViewController<SettingsView> {
  private let viewModel: SettingsViewModel
  
  private lazy var dataSource = createDataSource()
  
  private lazy var listItemCellRegistration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration>(handler: { cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in ip.item == 0 }
    cell.isLastInSection = { [weak self] ip in
      guard let collectionView = self?.customView.collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  })
  
  private lazy var footerCellRegistration = UICollectionView.CellRegistration<SettingsListFooterCell, SettingsListFooterCell.Model> { cell, indexPath, itemIdentifier in
    cell.configure(model: itemIdentifier)
  }

  private lazy var layout: UICollectionViewCompositionalLayout = {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [weak dataSource, weak self] sectionIndex, _ -> NSCollectionLayoutSection? in
        guard let dataSource else { return nil }
        let itemLayoutSize = NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(76)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
        
        let groupLayoutSize = NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(76)
        )
        let group = NSCollectionLayoutGroup.horizontal(
          layoutSize: groupLayoutSize,
          subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        return section
      },
      configuration: configuration
    )
    
    return layout
  }()
    
  init(viewModel: SettingsViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension SettingsViewController {
  func setup() {
    customView.collectionView.delegate = self
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
  }
  
  func setupBindings() {
    viewModel.titleUpdate = { [navigationItem] in
      navigationItem.title = $0
    }
    
    viewModel.itemsListUpdate = { [weak dataSource] items in
      dataSource?.apply(items, animatingDifferences: false)
    }
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<SettingsSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<SettingsSection, AnyHashable>(
      collectionView: customView.collectionView) { [listItemCellRegistration, footerCellRegistration]
        collectionView,
        indexPath,
        itemIdentifier in
        switch itemIdentifier {
        case let listItemConfiguration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(
            using: listItemCellRegistration,
            for: indexPath,
            item: listItemConfiguration
          )
        case let footerConfiguration as SettingsListFooterCell.Model:
          return collectionView.dequeueConfiguredReusableCell(
            using: footerCellRegistration,
            for: indexPath,
            item: footerConfiguration
          )
        default:
          return nil
        }
      }
    return dataSource
  }
}

extension SettingsViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case let listItem as TKUIListItemCell.Configuration:
      listItem.selectionClosure?()
    default: break
    }
  }
}

