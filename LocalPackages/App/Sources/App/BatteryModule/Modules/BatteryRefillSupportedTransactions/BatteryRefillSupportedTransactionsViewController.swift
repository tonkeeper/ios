import UIKit
import TKUIKit

final class BatteryRefillSupportedTransactionsViewController: GenericViewViewController<BatteryRefillSupportedTransactionsView> {
  private let viewModel: BatteryRefillSupportedTransactionsViewModel
  
  // MARK: - List
  
  private lazy var layout = createLayout()
  private lazy var dataSource = createDataSource()
  
  // MARK: - Init
  
  init(viewModel: BatteryRefillSupportedTransactionsViewModel) {
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

private extension BatteryRefillSupportedTransactionsViewController {
  func setup() {
    setupNavigationBar()
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
  }
  
  func setupBindings() {
    viewModel.didUpdateTitleView = { [weak self] model in
      self?.customView.titleView.configure(model: model)
      
    }
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
    
    if let navigationController, navigationController.viewControllers.count > 1 {
      customView.navigationBar.leftViews = [
        TKUINavigationBar.createBackButton {
          navigationController.popViewController(animated: true)
        }
      ]
    }
  }
  
  func createDataSource() -> BatteryRefillSupportedTransactions.DataSource {
    let listCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    
    let dataSource = BatteryRefillSupportedTransactions.DataSource(
      collectionView: customView.collectionView
    ) {
      collectionView, indexPath, itemIdentifier -> UICollectionViewCell? in
      let cell = collectionView.dequeueConfiguredReusableCell(
        using: listCellRegistration,
        for: indexPath,
        item: itemIdentifier.cellConfiguration)
      return cell
    }
    return dataSource
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

extension BatteryRefillSupportedTransactionsViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      shouldSelectItemAt indexPath: IndexPath) -> Bool {
    false
  }
  
  func collectionView(_ collectionView: UICollectionView, 
                      shouldHighlightItemAt indexPath: IndexPath) -> Bool {
    false
  }
}
