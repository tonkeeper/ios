import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class BrowserExploreViewController: GenericViewViewController<BrowserExploreView>, ScrollViewController {
  
  private let featuredView = BrowserExploreFeaturedView()
  private lazy var dataSource: BrowserExplore.DataSource = createDataSource()
  lazy var layout = createLayout()
  
  private let emptyView = BrowserExploreEmptyView()
  private let refreshControl = UIRefreshControl()
  
  private let viewModel: BrowserExploreViewModel
  
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
    guard customView.collectionView.contentOffset.y > customView.collectionView.adjustedContentInset.top else { return }
    customView.collectionView.setContentOffset(
      CGPoint(x: 0,
              y: -customView.collectionView.adjustedContentInset.top),
      animated: true
    )
  }
  
  func setListContentInsets(_ insets: UIEdgeInsets) {
    customView.topInset = insets.top
    customView.collectionView.contentInset = insets
  }
}

extension BrowserExploreViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView,
                      didSelectItemAt indexPath: IndexPath) {
    let item = dataSource
      .snapshot()
      .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case .app(let appItem):
      appItem.selectionHandler?()
    default:
      break
    }
  }
}

// MARK: - Private

private extension BrowserExploreViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    customView.collectionView.register(
      TKContainerCollectionViewCell.self,
      forCellWithReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier
    )
    customView.collectionView.refreshControl = refreshControl
    
    refreshControl.addAction(UIAction(handler: { [weak self] _ in
      self?.viewModel.reload()
    }), for: .valueChanged)
    
    featuredView.didSelectApp = { [weak self] dapp in
      self?.viewModel.selectFeaturedApp(dapp: dapp)
    }
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      if #available(iOS 15.0, *) {
        self?.dataSource.applySnapshotUsingReloadData(snapshot)
      } else {
        self?.dataSource.apply(snapshot, animatingDifferences: false)
      }
      self?.refreshControl.endRefreshing()
    }
    
    viewModel.didUpdateFeaturedItems = { [weak self] dapps in
      if dapps.isEmpty {
        self?.featuredView.isHidden = false
      } else {
        self?.featuredView.isHidden = false
        self?.featuredView.dapps = dapps
      }
    }
    
    viewModel.didUpdateEmptyView = { [weak self] model in
      self?.emptyView.configure(model: model)
    }
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: {
      [weak self] sectionIndex, environment -> NSCollectionLayoutSection? in
      guard let self = self else { return nil }
      
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[sectionIndex]
      switch section {
      case .empty:
        return createEmptySectionLayout()
      case let .apps(_, header, twoLinesAppsTitle):
        return BrowserCollectionLayout.appsSectionLayout(
          hasSectionTitle: header != nil,
          twoLinesAppsTitle: twoLinesAppsTitle
        )
      case .featured:
        return createFeaturedSectionLayout()
      case .ads:
        return createAdsSectionLayout()
      }
    }, configuration: configuration)
    
    return layout
  }
  
  func createEmptySectionLayout() -> NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1),
      heightDimension: .estimated(188)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(188)
    )
    let group: NSCollectionLayoutGroup
    if #available(iOS 16.0, *) {
      group = NSCollectionLayoutGroup.horizontalGroup(
        with: groupSize,
        repeatingSubitem: item,
        count: 1
      )
    } else {
      group = NSCollectionLayoutGroup.horizontal(
        layoutSize: groupSize,
        subitem: item,
        count: 1
      )
    }
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 16, trailing: 16)
    return section
  }
  
  func createFeaturedSectionLayout() -> NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .fractionalWidth(0.46)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    item.contentInsets = .init(top: 0, leading: 4, bottom: 0, trailing: 4)
    
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(50)
    )
    
    let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .init(top: 0, leading: 0, bottom: 16, trailing: 0)
    return section
  }
  
  func createAdsSectionLayout() -> NSCollectionLayoutSection {
    let sectionLayout: NSCollectionLayoutSection = .listItemsSection
    sectionLayout.contentInsets.bottom = 16
    sectionLayout.contentInsets.leading = 16
    sectionLayout.contentInsets.trailing = 16
    
    return sectionLayout
  }
  
  func createDataSource() -> BrowserExplore.DataSource {
    
    let connectedAppCellConfiguration = UICollectionView.CellRegistration<BrowserAppCollectionViewCell, BrowserAppCollectionViewCell.Configuration> { cell, indexPath, itemIdentifier in
      cell.configure(configuration: itemIdentifier)
    }
    let listItemCellConfiguration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    let dataSource = BrowserExplore.DataSource(collectionView: customView.collectionView) {
      [weak self] collectionView, indexPath, itemIdentifier in
      guard let self else { return UICollectionViewCell() }
      switch itemIdentifier {
      case .app(let appItem):
        let cell = collectionView.dequeueConfiguredReusableCell(
          using: connectedAppCellConfiguration,
          for: indexPath,
          item: appItem.configuration
        )
        cell.didLongPress = {
          appItem.longPressHandler?()
        }
        return cell
      case .empty:
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
          for: indexPath
        )
        (cell as? TKContainerCollectionViewCell)?.setContentView(emptyView)
        return cell
      case .featured:
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: TKContainerCollectionViewCell.reuseIdentifier,
          for: indexPath
        )
        (cell as? TKContainerCollectionViewCell)?.setContentView(featuredView)
        return cell
      case .ads(let adsItem):
        let cell = collectionView.dequeueConfiguredReusableCell(
          using: listItemCellConfiguration,
          for: indexPath,
          item: adsItem.configuration)
        cell.isHiglightable = false
        
        if let buttonAccessory = adsItem.buttonAccessory {
          let accessoryButton = TKListItemButtonAccessoryView()
          accessoryButton.configuration = buttonAccessory
          cell.defaultAccessoryViews = [accessoryButton]
        } else {
          cell.defaultAccessoryViews = []
        }

        return cell
      }
    }
    
    let sectionHeaderRegistration = UICollectionView.SupplementaryRegistration<BrowserExploreSectionHeaderView>(
      elementKind: BrowserExploreSectionHeaderView.reuseIdentifier) { _, _, _ in }
    dataSource.supplementaryViewProvider = {
      collectionView, _, indexPath in
      let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
      switch section {
      case let .apps(_, header, _):
        guard let header = header else { return nil }
        let headerView = collectionView.dequeueConfiguredReusableSupplementary(
          using: sectionHeaderRegistration,
          for: indexPath
        )
        
        headerView.configure(
          model: BrowserExploreSectionHeaderView.Model(
            title: header.title,
            isAllHidden: !header.hasAll,
            allTapAction: {
              header.allTapHandler?()
            }
          )
        )
        return headerView
      default:
        return nil
      }
    }
    return dataSource
  }
}
