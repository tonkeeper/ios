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
    
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false)
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
    let dataSource = DataSource(
      collectionView: customView.collectionView) {
        collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let listItem as SettingsListItem:
          let cell = collectionView.dequeueConfiguredReusableCell(
            using: listCellRegistration,
            for: indexPath,
            item: listItem.cellConfiguration)
          switch listItem.accessory {
          case .none:
            cell.defaultAccessoryViews = []
          case .chevron:
            let accessoryView = TKListItemIconAccessoryView()
            accessoryView.configuration = .chevron
            cell.defaultAccessoryViews = [accessoryView]
          case .icon(let configuration):
            let accessoryView = TKListItemIconAccessoryView()
            accessoryView.configuration = configuration
            cell.defaultAccessoryViews = [accessoryView]
          case .swift(let configuration):
            let accessoryView = TKListItemSwitchAccessoryView()
            accessoryView.configuration = configuration
            cell.defaultAccessoryViews = [accessoryView]
          case .text(let configuration):
            let accessoryView = TKListItemTextAccessoryView()
            accessoryView.configuration = configuration
            cell.defaultAccessoryViews = [accessoryView]
          }
          return cell
        case let item as SettingsAppInformationCell.Configuration:
          let cell = collectionView.dequeueConfiguredReusableCell(
            using: appInformationCellRegistration,
            for: indexPath,
            item: item)
          return cell
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
          return sectionLayout
        case .appInformation:
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

//public final class SettingsListViewController: GenericViewViewController<SettingsListView> {
//  typealias Section = SettingsListSection
//  typealias Item = AnyHashable
//  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
//  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
//  typealias SectionHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListTitleView>>
//  typealias SectionFooterRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<SettingsTextDescriptionView>>
//  
//  private lazy var dataSource: DataSource = createDataSource()
//  
//  private let viewModel: SettingsListViewModel
//  
//  init(viewModel: SettingsListViewModel) {
//    self.viewModel = viewModel
//    super.init(nibName: nil, bundle: nil)
//  }
//  
//  required init?(coder: NSCoder) {
//    fatalError("init(coder:) has not been implemented")
//  }
//  
//  public override func viewDidLoad() {
//    super.viewDidLoad()
//    setup()
//    setupBindings()
//    viewModel.viewDidLoad()
//  }
//}
//
//private extension SettingsListViewController {
//  func setup() {
//    setupNavigationBar()
//    customView.collectionView.delegate = self
//    customView.collectionView.setCollectionViewLayout(
//      createLayout(
//        dataSource: dataSource
//      ),
//      animated: false
//    )
//  }
//  
//  func setupBindings() {
//    viewModel.didUpdateTitleView = { [weak self] model in
//      self?.customView.titleView.configure(model: model)
//    }
//    
//    viewModel.didUpdateSnapshot = { [weak self] snapshot in
//      self?.dataSource.apply(snapshot, animatingDifferences: false)
//    }
//    
//    viewModel.didSelectItem = { [weak self] item in
//      guard let item, let indexPath = self?.dataSource.indexPath(for: item) else { return }
//      self?.customView.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
//    }
//    
//    viewModel.didShowPopupMenu = { [weak self] items, selectedIndex in
//      guard let cellIndex = self?.customView.collectionView.indexPathsForSelectedItems?.first,
//            let cell = self?.customView.collectionView.cellForItem(at: cellIndex) else {
//        return
//      }
//      
//      TKPopupMenuController.show(
//        sourceView: cell,
//        position: .topRight,
//        width: 0,
//        items: items,
//        selectedIndex: selectedIndex)
//    }
//  }
//  
//  func setupNavigationBar() {
//    guard let navigationController,
//          !navigationController.viewControllers.isEmpty else {
//      return
//    }
//    customView.navigationBar.leftViews = [
//      TKUINavigationBar.createBackButton {
//        navigationController.popViewController(animated: true)
//      }
//    ]
//  }
//  
//  func createDataSource() -> DataSource {
//    let itemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration>
//    { [weak viewModel, weak collectionView = self.customView.collectionView] cell, indexPath, identifier in
//      cell.isFirstInSection = { ip in ip.item == 0 }
//      cell.isLastInSection = { ip in
//        guard let collectionView = collectionView else { return false }
//        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
//      }
//      cell.configure(configuration: identifier)
//      if viewModel?.shouldSelect() == true {
//        cell.selectionAccessoryViews = self.createSelectionAccessoryViews()
//      }
//    }
//    
//    let buttonCellConfiguration = UICollectionView.CellRegistration<TKButtonCell, TKButtonCell.Model>
//    { cell, indexPath, identifier in
//      cell.configure(model: identifier)
//    }
//    
//    let appInformationCellConfiguration = UICollectionView.CellRegistration<SettingsAppInformationCell, SettingsAppInformationCell.Configuration>
//    { cell, indexPath, identifier in
//      cell.configure(configuration: identifier)
//    }
//    
//    let dataSource = DataSource(
//      collectionView: customView.collectionView) {
//        [itemCellConfiguration] collectionView,
//        indexPath,
//        itemIdentifier in
//        switch itemIdentifier {
//        case let configuration as TKUIListItemCell.Configuration:
//          return collectionView.dequeueConfiguredReusableCell(
//            using: itemCellConfiguration,
//            for: indexPath,
//            item: configuration
//          )
//        case let configuration as TKButtonCell.Model:
//          return collectionView.dequeueConfiguredReusableCell(
//            using: buttonCellConfiguration,
//            for: indexPath,
//            item: configuration
//          )
//        case let configuration as SettingsAppInformationCell.Configuration:
//          return collectionView.dequeueConfiguredReusableCell(
//            using: appInformationCellConfiguration,
//            for: indexPath,
//            item: configuration
//          )
//        default:
//          return nil
//        }
//      }
//    
//    let sectionFooterRegistration = SectionFooterRegistration(
//      elementKind: .sectionDescriptionFooterElementKind) { [weak self] supplementaryView, elementKind, indexPath in
//        guard let self else { return }
//        let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
//        switch section {
//        case .items(_, _, _, let bottomDescription):
//          guard let bottomDescription else { return}
//          supplementaryView.configure(model: bottomDescription)
//        }
//      }
//    let sectionHeaderRegistration = SectionHeaderRegistration(
//      elementKind: .sectionHeaderElementKind) { [weak self] supplementaryView, elementKind, indexPath in
//        guard let self else { return }
//        let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
//        switch section {
//        case .items(_, _, let header, _):
//          supplementaryView.configure(
//            model: TKListTitleView.Model(
//              title: header,
//              textStyle: .h3,
//              padding: UIEdgeInsets(top: 14, left: 0, bottom: 0, right: 0)
//            )
//          )
//        }
//      }
//    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in
//      switch kind {
//      case .sectionDescriptionFooterElementKind:
//        return collectionView.dequeueConfiguredReusableSupplementary(using: sectionFooterRegistration, for: indexPath)
//      case .sectionHeaderElementKind:
//        return collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderRegistration, for: indexPath)
//      default: return nil
//      }
//    }
//    
//    return dataSource
//  }
//  
//  func createLayout(dataSource: DataSource) -> UICollectionViewCompositionalLayout {
//    let configuration = UICollectionViewCompositionalLayoutConfiguration()
//    configuration.scrollDirection = .vertical
//    
//    let layout = UICollectionViewCompositionalLayout(
//      sectionProvider: { [dataSource] sectionIndex, _ in
//        let snapshot = dataSource.snapshot()
//        let section = snapshot.sectionIdentifiers[sectionIndex]
//        return Self.createLayoutSection(section: section)
//      },
//      configuration: configuration
//    )
//    return layout
//  }
//  
//  static func createLayoutSection(section: SettingsListSection) -> NSCollectionLayoutSection {
//    switch section {
//    case let .items(topPadding, _, header, bottomDescription):
//      return createItemsSection(
//        topPadding: topPadding,
//        hasHeader: header != nil,
//        hasFooter: bottomDescription != nil
//      )
//    }
//  }
//  
//  static func createItemsSection(topPadding: CGFloat,
//                                 hasHeader: Bool,
//                                 hasFooter: Bool) -> NSCollectionLayoutSection {
//    let itemLayoutSize = NSCollectionLayoutSize(
//      widthDimension: .fractionalWidth(1.0),
//      heightDimension: .estimated(76)
//    )
//    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
//    
//    let groupLayoutSize = NSCollectionLayoutSize(
//      widthDimension: .fractionalWidth(1.0),
//      heightDimension: .estimated(76)
//    )
//    let group = NSCollectionLayoutGroup.horizontal(
//      layoutSize: groupLayoutSize,
//      subitems: [item]
//    )
//    
//    let layoutSection = NSCollectionLayoutSection(group: group)
//    layoutSection.contentInsets = NSDirectionalEdgeInsets(
//      top: topPadding,
//      leading: 16,
//      bottom: 0,
//      trailing: 16
//    )
//    
//    var boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem]()
//    if hasHeader {
//      let headerSize = NSCollectionLayoutSize(
//        widthDimension: .fractionalWidth(1.0),
//        heightDimension: .estimated(28)
//      )
//      let header = NSCollectionLayoutBoundarySupplementaryItem(
//        layoutSize: headerSize,
//        elementKind: .sectionHeaderElementKind,
//        alignment: .top
//      )
//      boundarySupplementaryItems.append(header)
//    }
//
//    if hasFooter {
//      let footerSize = NSCollectionLayoutSize(
//        widthDimension: .fractionalWidth(1.0),
//        heightDimension: .estimated(48)
//      )
//      let footer = NSCollectionLayoutBoundarySupplementaryItem(
//        layoutSize: footerSize,
//        elementKind: .sectionDescriptionFooterElementKind,
//        alignment: .bottom
//      )
//      boundarySupplementaryItems.append(footer)
//    }
//    layoutSection.boundarySupplementaryItems = boundarySupplementaryItems
//    
//    return layoutSection
//  }
//  
//  func createSelectionAccessoryViews() -> [UIView] {
//    var configuration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
//    configuration.contentPadding.right = 16
//    configuration.iconTintColor = .Accent.blue
//    configuration.content.icon = .TKUIKit.Icons.Size28.donemarkOutline
//    let button = TKButton(configuration: configuration)
//    button.isUserInteractionEnabled = false
//    return [button]
//  }
//}
//
//extension SettingsListViewController: UICollectionViewDelegate {
//  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//    let snapshot = dataSource.snapshot()
//    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
//    switch item {
//    case let configuration as TKUIListItemCell.Configuration:
//      configuration.selectionClosure?()
//    default:
//      break
//    }
//  }
//}
//
//private extension String {
//  static let sectionHeaderElementKind = "SectionHeaderElementKind"
//  static let sectionDescriptionFooterElementKind = "SectionDescriptionFooterElementKind"
//}
