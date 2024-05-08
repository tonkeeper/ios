import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class BrowserExploreViewController: GenericViewViewController<BrowserExploreView>, ScrollViewController {
  
  typealias DataSource = UICollectionViewDiffableDataSource<BrowserExploreSection, AnyHashable>
  private let viewModel: BrowserExploreViewModel
  
  private lazy var dataSource = createDataSource()
  
  private lazy var listItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in
      return ip.item % 3 == 0
    }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView else { return false }
      return (ip.item + 1) % 3 == 0 || ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  }
  
  private lazy var sectionHeaderRegistration = UICollectionView.SupplementaryRegistration<BrowserExploreSectionHeaderView>(
    elementKind: BrowserExploreSectionHeaderView.reuseIdentifier) { _, _, _ in }
  
  
  init(viewModel: BrowserExploreViewModel) {
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
  
  func scrollToTop() {
    
  }
  
  func setListContentInsets(_ insets: UIEdgeInsets) {
    customView.collectionView.contentInset = insets
  }
}

extension BrowserExploreViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let item = dataSource
      .snapshot()
      .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case let listItem as TKUIListItemCell.Configuration:
      listItem.selectionClosure?()
    default: break
    }
  }
}

// MARK: - Private

private extension BrowserExploreViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(createLayout(), animated: false)
    customView.collectionView.delegate = self
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false)
    }
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let layout = UICollectionViewCompositionalLayout {
      [weak self] sectionIndex, environment -> NSCollectionLayoutSection? in
      guard let self = self else { return nil }
      
      let itemSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1),
        heightDimension: .absolute(84)
      )
      let item = NSCollectionLayoutItem(layoutSize: itemSize)
      item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8)
      
      let snapshot = dataSource.snapshot()
      let itemsCount = snapshot.numberOfItems(inSection: snapshot.sectionIdentifiers[sectionIndex])
      let groupItemsCount = itemsCount < 3 ? itemsCount : 3
      
      let widthDimension: NSCollectionLayoutDimension
      if itemsCount <= 3 {
        widthDimension = .absolute(environment.container.effectiveContentSize.width - 24)
      } else {
        widthDimension = .fractionalWidth(0.88)
      }
      let groupSize = NSCollectionLayoutSize(
        widthDimension: widthDimension,
        heightDimension: .absolute(CGFloat(groupItemsCount) * 84)
      )
      
      let group: NSCollectionLayoutGroup
    
      if #available(iOS 16.0, *) {
        group = NSCollectionLayoutGroup.verticalGroup(
          with: groupSize,
          repeatingSubitem: item,
          count: groupItemsCount
        )
      } else {
        group = NSCollectionLayoutGroup.vertical(
          layoutSize: groupSize,
          subitem: item,
          count: groupItemsCount
        )
      }
      
      let section = NSCollectionLayoutSection(group: group)
      section.orthogonalScrollingBehavior = .groupPaging
      section.contentInsets = .init(top: 10, leading: 16, bottom: 16, trailing: 0)
      
      let headerSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(56)
      )
      let header = NSCollectionLayoutBoundarySupplementaryItem(
        layoutSize: headerSize,
        elementKind: BrowserExploreSectionHeaderView.reuseIdentifier,
        alignment: .top
      )
      section.boundarySupplementaryItems = [header]
      
      return section

    }
    return layout
  }
  
  func createDataSource() -> DataSource {
    let dataSource = DataSource(collectionView: customView.collectionView) { [listItemCellConfiguration] collectionView, indexPath, itemIdentifier in
      switch itemIdentifier {
      case let listCellConfiguration as TKUIListItemCell.Configuration:
        return collectionView.dequeueConfiguredReusableCell(using: listItemCellConfiguration, for: indexPath, item: listCellConfiguration)
      default: return nil
      }
    }
    
    dataSource.supplementaryViewProvider = { [sectionHeaderRegistration, dataSource] collectionView, elementKind, indexPath in
      switch elementKind {
      case BrowserExploreSectionHeaderView.reuseIdentifier:
        let sectionHeader = collectionView.dequeueConfiguredReusableSupplementary(
          using: sectionHeaderRegistration,
          for: indexPath
        )
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        switch section {
        case let .regular(title, hasAll, _):
          sectionHeader.configure(model: BrowserExploreSectionHeaderView.Model(
            title: title,
            isAllHidden: !hasAll,
            allTapAction: { [weak self] in
              self?.viewModel.didSelectCategoryAll(index: indexPath.section)
            })
          )
        }
        return sectionHeader
      default:
        return nil
      }
    }
    
    return dataSource
  }
}

