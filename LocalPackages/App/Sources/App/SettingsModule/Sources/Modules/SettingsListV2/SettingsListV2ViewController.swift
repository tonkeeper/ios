import UIKit
import TKUIKit

public final class SettingsListV2ViewController: GenericViewViewController<SettingsListV2View> {
  typealias Section = SettingsListV2Section
  typealias Item = AnyHashable
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  
  private lazy var dataSource: DataSource = createDataSource()
  
  private let viewModel: SettingsListV2ViewModel
  
  init(viewModel: SettingsListV2ViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    navigationController?.setNavigationBarHidden(false, animated: true)
  }
}

private extension SettingsListV2ViewController {
  func setup() {
    customView.collectionView.delegate = self
    customView.collectionView.setCollectionViewLayout(
      createLayout(
        dataSource: dataSource
      ),
      animated: false
    )
  }
  
  func setupBindings() {
    viewModel.didUpdateTitle = { [weak self] title in
      self?.navigationItem.title = title
    }
    
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    viewModel.didSelectItem = { [weak self] item in
      guard let item, let indexPath = self?.dataSource.indexPath(for: item) else { return }
      self?.customView.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
    }
  }
  
  func createDataSource() -> DataSource {
    let itemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration>
    { [weak viewModel, weak collectionView = self.customView.collectionView] cell, indexPath, identifier in
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
      cell.configure(configuration: identifier)
      if viewModel?.shouldSelect() == true {
        cell.selectionAccessoryViews = self.createSelectionAccessoryViews()
      }
    }
    
    let dataSource = DataSource(
      collectionView: customView.collectionView) {
        [itemCellConfiguration] collectionView,
        indexPath,
        itemIdentifier in
        switch itemIdentifier {
        case let configuration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(
            using: itemCellConfiguration,
            for: indexPath,
            item: configuration
          )
        default:
          return nil
        }
      }
    return dataSource
  }
  
  func createLayout(dataSource: DataSource) -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[sectionIndex]
        return Self.createLayoutSection(section: section)
      },
      configuration: configuration
    )
    return layout
  }
  
  static func createLayoutSection(section: SettingsListV2Section) -> NSCollectionLayoutSection {
    switch section {
    case .items(let topPadding, _):
      return createItemsSection(topPadding: topPadding)
    }
  }
  
  static func createItemsSection(topPadding: CGFloat) -> NSCollectionLayoutSection {
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
    
    let layoutSection = NSCollectionLayoutSection(group: group)
    layoutSection.contentInsets = NSDirectionalEdgeInsets(
      top: topPadding,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return layoutSection
  }
  
  func createSelectionAccessoryViews() -> [UIView] {
    var configuration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
    configuration.contentPadding.right = 16
    configuration.iconTintColor = .Accent.blue
    configuration.content.icon = .TKUIKit.Icons.Size28.donemarkOutline
    let button = TKButton(configuration: configuration)
    button.isUserInteractionEnabled = false
    return [button]
  }
}

extension SettingsListV2ViewController: UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case let configuration as TKUIListItemCell.Configuration:
      configuration.selectionClosure?()
    default:
      break
    }
  }
}
