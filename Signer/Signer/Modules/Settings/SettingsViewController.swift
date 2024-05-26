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
        let snapshot = dataSource.snapshot()
        let snapshotSection = snapshot.sectionIdentifiers[sectionIndex]
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
        
        let headerSize = NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(0)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
          layoutSize: headerSize,
          elementKind: .sectionHeaderKind,
          alignment: .top
        )
    
        let section = NSCollectionLayoutSection(group: group)
        if let snapshotSectionTitle = snapshotSection.title, !snapshotSectionTitle.isEmpty {
          section.boundarySupplementaryItems = [header]
        }
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
    customView.collectionView.register(
      TKCollectionViewSupplementaryContainerView<TKListTitleView>.self,
      forSupplementaryViewOfKind: .sectionHeaderKind,
      withReuseIdentifier: TKCollectionViewSupplementaryContainerView<TKListTitleView>.reuseIdentifier
    )
    customView.collectionView.contentInset.top = 16
  }
  
  func setupBindings() {
    viewModel.titleUpdate = { [navigationItem] in
      navigationItem.title = $0
    }
    
    viewModel.itemsListUpdate = { [weak dataSource] items in
      dataSource?.apply(items, animatingDifferences: false)
    }
    
    viewModel.showPopupMenu = { [weak self] items, selectedIndex, indexPath in
      guard let cell = self?.customView.collectionView.cellForItem(at: indexPath) else { return }
      TKPopupMenuController.show(
        sourceView: cell,
        position: .topRight,
        width: 0,
        items: items,
        selectedIndex: selectedIndex)
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
    
    dataSource.supplementaryViewProvider = { [dataSource] collectionView, kind, indexPath in
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      let view = collectionView.dequeueReusableSupplementaryView(
        ofKind: .sectionHeaderKind,
        withReuseIdentifier: TKCollectionViewSupplementaryContainerView<TKListTitleView>.reuseIdentifier,
        for: indexPath) as? TKCollectionViewSupplementaryContainerView<TKListTitleView>
      view?.contentView.configure(model: TKListTitleView.Model(title: section.title, textStyle: .h3))
      
      return view
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

private extension String {
  static let sectionHeaderKind = "SectionHeaderKind"
}

