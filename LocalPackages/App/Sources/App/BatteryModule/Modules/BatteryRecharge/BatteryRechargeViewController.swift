import UIKit
import TKUIKit

final class BatteryRechargeViewController: GenericViewViewController<BatteryRechargeView> {
  private let viewModel: BatteryRechargeViewModel
  
  // MARK: - List
  
  private lazy var layout = createLayout()
  private lazy var dataSource = createDataSource()
  
  // MARK: - Title
  
  private let titleLabel = UILabel()
  
  // MARK: - Init
  
  init(viewModel: BatteryRechargeViewModel) {
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

private extension BatteryRechargeViewController {
  func setup() {
    customView.navigationBar.apperance = .transparent
    setupNavigationBar()
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    customView.collectionView.register(TKButtonCell.self, forCellWithReuseIdentifier: "ButtonCell")
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      guard let self else { return }
      self.dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    viewModel.didUpdateTitle = { [weak self] title in
      self?.titleLabel.attributedText = title.withTextStyle(.h3, color: .Text.primary)
    }
  }
  
  private func setupNavigationBar() {
    customView.navigationBar.leftViews = [titleLabel]
    
    customView.navigationBar.rightViews = [
      TKUINavigationBar.createCloseButton { [weak self] in
        self?.dismiss(animated: true)
      }
    ]
    
  }
  
  func createDataSource() -> BatteryRecharge.DataSource {
    let listCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    
    let dataSource = BatteryRecharge.DataSource(
      collectionView: customView.collectionView
    ) { [weak self]
      collectionView, indexPath, itemIdentifier -> UICollectionViewCell? in
      guard let self else { return nil }
      switch itemIdentifier {
      case .listItem(let listItem):
        guard let cellConfiguration = self.viewModel.listCellConfiguration(identifier: listItem.identifier) else {
          return nil
        }
        
        let cell = collectionView.dequeueConfiguredReusableCell(
          using: listCellRegistration,
          for: indexPath,
          item: cellConfiguration)
        cell.defaultAccessoryViews = [createRadioButtonAccessoryView(isEnable: listItem.isEnable,
                                                                     isSelected: false)]
        cell.selectionAccessoryViews = [createRadioButtonAccessoryView(isEnable: listItem.isEnable,
                                                                       isSelected: true)]
        cell.leftAccessoryViews = [self.createAccessoryBatteryView(item: listItem)]
        return cell
      case .continueButton:
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ButtonCell", for: indexPath)
        if let configuration = viewModel.continueButtonCellConfiguration {
          (cell as? TKButtonCell)?.configure(model: configuration)
        }
        return cell
      }
    }
    return dataSource
  }
  
  func createRadioButtonAccessoryView(isEnable: Bool, isSelected: Bool) -> UIView {
    let radioButton = RadioButton()
    radioButton.padding.right = 16
    radioButton.size = 28
    radioButton.tintColors = [.selected: .Button.primaryBackground, .deselected: .Icon.tertiary]
    radioButton.isEnabled = isEnable
    radioButton.isSelected = isSelected
    radioButton.isUserInteractionEnabled = false
    return radioButton
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
  
  private func createAccessoryBatteryView(item: BatteryRecharge.ListItem) -> UIView  {
    let batteryView = BatteryView(size: .size44)
    batteryView.padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
    batteryView.state = item.batteryViewState
    return batteryView
  }
}

extension BatteryRechargeViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case .listItem(let listItem):
      listItem.onSelection()
    default: break
    }
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      shouldSelectItemAt indexPath: IndexPath) -> Bool {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case .listItem(let listItem):
      return listItem.isEnable
    case .continueButton:
      return false
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, 
                      shouldHighlightItemAt indexPath: IndexPath) -> Bool {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case .listItem(let listItem):
      return listItem.isEnable
    case .continueButton:
      return false
    }
  }
}
