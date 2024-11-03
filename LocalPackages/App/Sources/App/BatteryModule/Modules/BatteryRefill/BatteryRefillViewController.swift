import UIKit
import TKUIKit

final class BatteryRefillViewController: GenericViewViewController<BatteryRefillView> {
  private let viewModel: BatteryRefillViewModel
  
  // MARK: - List
  
  private lazy var layout = createLayout()
  private lazy var dataSource = createDataSource()
  
  // MARK: - Init
  
  init(viewModel: BatteryRefillViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension BatteryRefillViewController {
  func setup() {
    customView.navigationBar.apperance = .transparent
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    
    setupNavigationBar()
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      guard let self else { return }
      self.dataSource.apply(snapshot, animatingDifferences: false)
    }
  }
  
  private func setupNavigationBar() {
    if presentingViewController != nil {
      customView.navigationBar.rightViews = [
        TKUINavigationBar.createCloseButton { [weak self] in
          self?.dismiss(animated: true)
        }
      ]
    }
  }
  
  func createDataSource() -> BatteryRefill.DataSource {
    let listCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    let headerCellRegistration = BatteryRefillHeaderCellRegistration.registration(collectionView: customView.collectionView)
    let footerCellRegistration = BatteryRefillFooterCellRegistration.registration(collectionView: customView.collectionView)
    
    let dataSource = BatteryRefill.DataSource(
      collectionView: customView.collectionView
    ) {
      [weak self, weak viewModel] collectionView, indexPath, itemIdentifier -> UICollectionViewCell? in
      guard let self, let viewModel else { return nil }
      switch itemIdentifier {
      case .header:
        guard let headerCellConfiguration = viewModel.getHeaderCellConfiguration() else { return nil }
        let cell = collectionView.dequeueConfiguredReusableCell(using: headerCellRegistration, for: indexPath, item: headerCellConfiguration)
        return cell
      case .listItem(let listItem):
        let configuration = viewModel.getListItemCellConfiguration(identifier: listItem.identifier) ?? .default
        let cell = collectionView.dequeueConfiguredReusableCell(using: listCellRegistration, for: indexPath, item: configuration)
        cell.leftAccessoryViews = []
        cell.defaultAccessoryViews = [TKListItemAccessory.chevron.view]
        return cell
      case .inAppPurchase(let purhaseItem):
        let configuration = viewModel.getInAppPurchaseCellConfiguration(identifier: purhaseItem.identifier) ?? .default
        let cell = collectionView.dequeueConfiguredReusableCell(using: listCellRegistration, for: indexPath, item: configuration)
        cell.leftAccessoryViews = [createAccessoryBatteryView(item: purhaseItem)]
        cell.defaultAccessoryViews = [createAccessoryBuyButton(item: purhaseItem)]
        return cell
      case .footer:
        guard let headerCellConfiguration = viewModel.getFooterCellConfiguration() else { return nil }
        let cell = collectionView.dequeueConfiguredReusableCell(using: footerCellRegistration, for: indexPath, item: headerCellConfiguration)
        return cell
      }
    }
    
    return dataSource
  }
  
  
  private func createAccessoryBatteryView(item: BatteryRefill.InAppPurchaseItem) -> UIView  {
    let batteryView = BatteryView(size: .size44)
    batteryView.padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
    batteryView.state = .fill(item.batteryPercent)
    return batteryView
  }
  
  private func createAccessoryBuyButton(item: BatteryRefill.InAppPurchaseItem) -> UIView {
    return TKListItemAccessory.button(
      TKListItemButtonAccessoryView.Configuration(
        title: item.buttonTitle,
        category: .primary,
        isEnable: item.isEnable,
        action: { [weak viewModel] in
          viewModel?.purchaseItem(productIdentifier: item.identifier)
        }
      )
    ).view
  }

  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, _ in
      let itemLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(96)
      )
      let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
      
      let groupLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(96)
      )
      let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: groupLayoutSize,
        subitems: [item]
      )
      
      let layoutSection = NSCollectionLayoutSection(group: group)
      layoutSection.contentInsets = NSDirectionalEdgeInsets(
        top: 0,
        leading: 16,
        bottom: 16,
        trailing: 16
      )
      
      return layoutSection
    }, configuration: configuration)
    
    return layout
  }
}

extension BatteryRefillViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case .listItem(let item):
      item.onSelection?()
    default: break
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    let snapshot = dataSource.snapshot()
    return snapshot.sectionIdentifiers[indexPath.section].isSelectable
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
    let snapshot = dataSource.snapshot()
    return snapshot.sectionIdentifiers[indexPath.section].isSelectable
  }
}
