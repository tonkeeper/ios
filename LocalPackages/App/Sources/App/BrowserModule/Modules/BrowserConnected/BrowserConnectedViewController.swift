import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class BrowserConnectedViewController: GenericViewViewController<BrowserConnectedView>, ScrollViewController {
  
  typealias DataSource = UICollectionViewDiffableDataSource<BrowserConnectedSection, AnyHashable>
  private let viewModel: BrowserConnectedViewModel
    
  private lazy var dataSource = createDataSource()
    
  private lazy var appCellConfiguration = UICollectionView.CellRegistration<
    BrowserConnectedAppCell,
    BrowserConnectedAppCell.Configuration
  > { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
  }
  
  lazy var layout = createLayout()
  
  init(viewModel: BrowserConnectedViewModel) {
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

extension BrowserConnectedViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    viewModel.selectApp(index: indexPath.item)
  }
}

// MARK: - Private

private extension BrowserConnectedViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    viewModel.didUpdateViewState = { [weak self] state in
      self?.customView.state = state
    }
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.interSectionSpacing = 16
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: {
      [weak self] sectionIndex, environment -> NSCollectionLayoutSection? in
      guard let self = self else { return nil }
      
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[sectionIndex]
      switch section {
      case .apps:
        return appsSectionLayout(
          snapshot: snapshot,
          section: section,
          environment: environment
        )
      }
    }, configuration: configuration)
    
    return layout
  }
  
  func appsSectionLayout(snapshot: NSDiffableDataSourceSnapshot<BrowserConnectedSection, AnyHashable>,
                            section: BrowserConnectedSection,
                            environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1/4),
      heightDimension: .absolute(104)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8)

    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1),
      heightDimension: .estimated(104)
    )
    
    let group: NSCollectionLayoutGroup
  
    if #available(iOS 16.0, *) {
      group = NSCollectionLayoutGroup.horizontalGroup(
        with: groupSize,
        repeatingSubitem: item,
        count: 4
      )
    } else {
      group = NSCollectionLayoutGroup.horizontal(
        layoutSize: groupSize,
        subitem: item,
        count: 4
      )
    }
    group.contentInsets = .init(top: 0, leading: 12, bottom: 0, trailing: 12)
    
    let section = NSCollectionLayoutSection(group: group)
    return section
  }
  
  func createDataSource() -> DataSource {
    let dataSource = DataSource(collectionView: customView.collectionView) {
      [appCellConfiguration] collectionView,
      indexPath,
      itemIdentifier in
      switch itemIdentifier {
      case let configuration as BrowserConnectedAppCell.Configuration:
        return collectionView.dequeueConfiguredReusableCell(
          using: appCellConfiguration,
          for: indexPath,
          item: configuration
        )
      default: return nil
      }
    }

    return dataSource
  }
}
