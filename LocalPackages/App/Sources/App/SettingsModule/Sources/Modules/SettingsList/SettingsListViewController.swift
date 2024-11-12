import UIKit
import TKUIKit

final class SettingsListViewController: GenericViewViewController<SettingsListView> {
  typealias Section = SettingsListSection
  typealias Item = AnyHashable
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  
  private let viewModel: SettingsListViewModel

  init(viewModel: SettingsListViewModel) {
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
  
  private func setup() {
    setupNavigationBar()
    customView.collectionView.collectionViewLayout = layout
    customView.collectionView.delegate = self
  }
  
  private func setupBindings() {
    viewModel.didUpdateTitleView = { [weak self] model in
      self?.customView.titleView.configure(model: model)
    }
    
    viewModel.didUpdateSnapshot = { [weak self] snapshot, animated in
      self?.dataSource.apply(snapshot, animatingDifferences: animated, completion: {
        let selectedItems = self?.viewModel.selectedItems
        selectedItems?.forEach {
          guard let index = snapshot.indexOfItem($0) else { return }
          let indexPath = IndexPath(item: index, section: 0)
          self?.customView.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
      })
    }
  }
  
  private func setupNavigationBar() {
    guard let navigationController,
          !navigationController.viewControllers.isEmpty else {
      return
    }
    customView.navigationBar.leftViews = [
      TKUINavigationBar.createBackButton {
        navigationController.popViewController(animated: true)
      }
    ]
  }

  private lazy var dataSource: DataSource = {
    let listCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    let appInformationCellRegistration = SettingsAppInformationCellRegistration.registration
    let buttonCellRegistration = TKButtonCollectionViewCellRegistration.registration()
    let notificationBannerCellRegistration = NotificationBannerCellRegistration.registration
    
    let dataSource = DataSource(
      collectionView: customView.collectionView) {
        collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let listItem as SettingsListItem:
          let cell = collectionView.dequeueConfiguredReusableCell(
            using: listCellRegistration,
            for: indexPath,
            item: listItem.cellConfiguration)
          if let accessoryView = listItem.accessory?.view {
            cell.defaultAccessoryViews = [accessoryView]
          } else {
            cell.defaultAccessoryViews = []
          }
          
          if let selectionAccessoryView = listItem.selectAccessory?.view {
            cell.selectionAccessoryViews = [selectionAccessoryView]
          } else {
            cell.selectionAccessoryViews = []
          }
          return cell
        case let item as SettingsAppInformationCell.Configuration:
          let cell = collectionView.dequeueConfiguredReusableCell(
            using: appInformationCellRegistration,
            for: indexPath,
            item: item)
          cell.handleDiamondAction = { [weak self] in
            self?.viewModel.openDevMenu()
          }
          return cell
        case let item as SettingsButtonListItem:
          let cell = collectionView.dequeueConfiguredReusableCell(
            using: buttonCellRegistration,
            for: indexPath,
            item: item.cellConfiguration)
          return cell
        case let item as SettingsNotificationBannerListItem:
          let cell = collectionView.dequeueConfiguredReusableCell(
            using: notificationBannerCellRegistration,
            for: indexPath,
            item: item.cellConfiguration)
          return cell
        default:
          return nil
        }
      }
    
    let sectionHeaderRegistration = SettingsListSectionHeaderViewRegistration.registration()
    let sectionFooterRegistration = SettingsListSectionFooterViewRegistration.registration()
    dataSource.supplementaryViewProvider = { [weak self] collectionView, elementKind, indexPath in
      guard let snapshot = self?.dataSource.snapshot() else { return nil }
      switch elementKind {
      case SettingsListSectionHeaderView.elementKind:
        let snapshotSection = snapshot.sectionIdentifiers[indexPath.section]
        switch snapshotSection {
        case .listItems(let section):
          guard let configuration = section.headerConfiguration else { return nil }
          let view = collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderRegistration, for: indexPath)
          view.configuration = configuration
          return view
        default:
          return nil
        }
      case SettingsListSectionFooterView.elementKind:
        let snapshotSection = snapshot.sectionIdentifiers[indexPath.section]
        switch snapshotSection {
        case .listItems(let section):
          guard let configuration = section.footerConfiguration else { return nil }
          let view = collectionView.dequeueConfiguredReusableSupplementary(using: sectionFooterRegistration, for: indexPath)
          view.configuration = configuration
          return view
        default:
          return nil
        }
      default:
        return nil
      }
    }
    
    return dataSource
  }()
  
  private var layout: UICollectionViewCompositionalLayout {
    let widthDimension: NSCollectionLayoutDimension = .fractionalWidth(1.0)
    let heightDimension: NSCollectionLayoutDimension = .estimated(76)
    
    let itemSize = NSCollectionLayoutSize(
      widthDimension: widthDimension,
      heightDimension: heightDimension
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
  
    let groupSize = NSCollectionLayoutSize(
      widthDimension: widthDimension,
      heightDimension: heightDimension
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0, leading: 32, bottom: 16, trailing: 32
    )
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical

    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [weak dataSource] sectionIndex, _ in
        guard let dataSource else { return nil }
        let snapshotSection = dataSource.snapshot().sectionIdentifiers[sectionIndex]
        
        switch snapshotSection {
        case .listItems(let section):
          let sectionLayout: NSCollectionLayoutSection = .listItemsSection
          sectionLayout.contentInsets.top = section.topPadding
          sectionLayout.contentInsets.bottom = section.bottomPadding
          
          if section.headerConfiguration != nil {
            let headerSize = NSCollectionLayoutSize(
              widthDimension: .fractionalWidth(1.0),
              heightDimension: .estimated(100)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
              layoutSize: headerSize,
              elementKind: SettingsListSectionHeaderView.elementKind,
              alignment: .top
            )
            
            sectionLayout.boundarySupplementaryItems.append(header)
          }
          
          if section.footerConfiguration != nil {
            let footerSize = NSCollectionLayoutSize(
              widthDimension: .fractionalWidth(1.0),
              heightDimension: .estimated(100)
            )
            let footer = NSCollectionLayoutBoundarySupplementaryItem(
              layoutSize: footerSize,
              elementKind: SettingsListSectionFooterView.elementKind,
              alignment: .bottom
            )
            sectionLayout.boundarySupplementaryItems.append(footer)
          }
          
          return sectionLayout
        case .appInformation, .button:
          let itemLayoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(110)
          )
          let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
          
          let groupLayoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(110)
          )
          let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupLayoutSize,
            subitems: [item]
          )
          let section = NSCollectionLayoutSection(group: group)
          section.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 16,
            bottom: 0,
            trailing: 16
          )
          
          return section
        }
      },
      configuration: configuration
    )
    return layout
  }
}

extension SettingsListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    let cell = collectionView.cellForItem(at: indexPath)
    switch item {
    case let listItem as SettingsListItem:
      listItem.onSelection?(cell)
    default:
      return
    }
  }
}
