import UIKit
import TKUIKit
import TKLocalize

enum SettingsPurchasesSection: Hashable {
  case visible
  case hidden
  case spam
  
  var title: String {
    switch self {
    case .visible:
      TKLocales.Settings.Purchases.Sections.visible
    case .hidden:
      TKLocales.Settings.Purchases.Sections.hidden
    case .spam:
      TKLocales.Settings.Purchases.Sections.spam
    }
  }
}

final class SettingsPurchasesViewController: GenericViewViewController<SettingsPurchasesView> {
  typealias Item = String
  typealias Section = SettingsPurchasesSection
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  typealias RegularItemConfiguration = UICollectionView.CellRegistration<SettingsPurchasesItemCell,
                                                                         String>
  typealias ButtonCellConfiguration = UICollectionView.CellRegistration<TKButtonCell, 
                                                                          TKButtonCell.Model>
  typealias HeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListTitleView>>
  typealias SectionFooterRegistration = UICollectionView.SupplementaryRegistration<SettingsPurchasesSectionButtonView>
  
  private weak var detailsViewController: TKBottomSheetViewController?
  
  // MARK: - List
  
  private lazy var layout = createLayout()
  private lazy var dataSource = createDataSource()
  
  private let viewModel: SettingsPurchasesViewModel
  
  init(viewModel: SettingsPurchasesViewModel) {
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

private extension SettingsPurchasesViewController {
  func setup() {
    setupNavigationBar()
    
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
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
  
  func setupBindings() {
    viewModel.didUpdateTitleView = { [weak self] model in
      self?.customView.titleView.configure(model: model)
    }
    
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      guard let self else { return }
      self.dataSource.apply(snapshot, animatingDifferences: false, completion: {
      })
    }
    
    viewModel.didOpenDetails = { [weak self] configuration in
      guard let self else { return }
      let viewController = PurchasesManagementDetailsViewController(configuration: configuration)
      let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)
      bottomSheetViewController.present(fromViewController: self)
      self.detailsViewController = bottomSheetViewController
    }
    
    viewModel.didHideDetails = { [weak self] in
      guard let detailsViewController = self?.detailsViewController else { return }
      detailsViewController.dismiss()
    }
  }
  
  func createDataSource() -> DataSource {
    let regularItemConfiguration = RegularItemConfiguration { [weak viewModel, weak collectionView = self.customView.collectionView]
      cell, indexPath, itemIdentifier in
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
      guard let model = viewModel?.getItemCellModel(identifier: itemIdentifier) else { return }
      cell.configure(model: model)
    }
    
    let headerRegistration = HeaderRegistration(elementKind: .sectionHeaderIdentifier) { [weak self] supplementaryView, elementKind, indexPath in
      guard let self else { return }
      let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
      supplementaryView.configure(model: TKListTitleView.Model(title: section.title, textStyle: .h3))
    }
    
    let sectionFooterRegistration = SectionFooterRegistration(elementKind: .sectionFooterIdentifier) { [weak self] supplementaryView, elementKind, indexPath in
      guard let self else { return }
      let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
      if let model = viewModel.sectionFooterModel(section: section) {
        supplementaryView.configure(model: model)
      }
    }
    
    let dataSource = DataSource(collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
      collectionView.dequeueConfiguredReusableCell(
        using: regularItemConfiguration,
        for: indexPath,
        item: itemIdentifier)
    }
    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
      switch kind {
      case .sectionHeaderIdentifier:
        return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
      case .sectionFooterIdentifier:
        return collectionView.dequeueConfiguredReusableSupplementary(using: sectionFooterRegistration, for: indexPath)
      default: return nil
      }
    }
    
    return dataSource
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak viewModel, dataSource] sectionIndex, _ in
      
      let hasFooter = viewModel?.sectionFooterModel(section: dataSource.snapshot().sectionIdentifiers[sectionIndex]) != nil
      
      let itemLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(76)
      )
      let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
      
      let groupLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(76)
      )
      let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: groupLayoutSize,
        subitems: [item]
      )
      
      let layoutSection = NSCollectionLayoutSection(group: group)
      layoutSection.contentInsets = NSDirectionalEdgeInsets(
        top: 0,
        leading: 16,
        bottom: hasFooter ? 0 : 16,
        trailing: 16
      )
      let headerSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(56)
      )
      let header = NSCollectionLayoutBoundarySupplementaryItem(
        layoutSize: headerSize,
        elementKind: .sectionHeaderIdentifier,
        alignment: .top
      )
      layoutSection.boundarySupplementaryItems.append(header)
      
      if hasFooter {
        let footerSize = NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .estimated(52)
        )
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
          layoutSize: footerSize,
          elementKind: .sectionFooterIdentifier,
          alignment: .bottom
        )
        layoutSection.boundarySupplementaryItems.append(footer)
      }
      
      return layoutSection
    }, configuration: configuration)
    
    return layout
  }
}

extension SettingsPurchasesViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    viewModel.didTapItem(identifier: item)
  }
}

private extension String {
  static let sectionHeaderIdentifier = "SectionHeaderIdentifier"
  static let sectionFooterIdentifier = "SectionFooterIdentifier"
}
