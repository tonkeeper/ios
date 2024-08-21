import UIKit
import TKUIKit
import TKCoordinator

enum CollectiblesListSection: Hashable {
  case all
}

enum CollectiblesListItem: Hashable {
  case nft(identifier: String)
}

final class CollectiblesListViewController: GenericViewViewController<CollectiblesListView>, ScrollViewController, ContentListEmptyViewControllerListViewController {
  typealias Item = CollectiblesListItem
  typealias Section = CollectiblesListSection
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  typealias CollectibleCellConfiguration = UICollectionView.CellRegistration<CollectibleCollectionViewCell, String>
  
  private lazy var dataSource = createDataSource()
  private lazy var layout = createLayout()
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  
  private let viewModel: CollectiblesListViewModel
  
  init(viewModel: CollectiblesListViewModel) {
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
}

private extension CollectiblesListViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: true)
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false)
    }
  }
  
  func createDataSource() -> DataSource {
    let nftCellConfiguration = CollectibleCellConfiguration {
      [weak viewModel] cell, indexPath, itemIdentifier in
      
      guard let model = viewModel?.getNFTCellModel(identifier: itemIdentifier) else { return }
      cell.configure(model: model)
    }
    
    let dataSource = DataSource(collectionView: customView.collectionView) {
      collectionView, indexPath, itemIdentifier in
      switch itemIdentifier {
      case .nft(let identifier):
        return collectionView.dequeueConfiguredReusableCell(
          using: nftCellConfiguration,
          for: indexPath,
          item: identifier
        )
      }
    }
    return dataSource
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { _, _ in
        let item = NSCollectionLayoutItem(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1/3),
            heightDimension: .estimated(166)
          )
        )
        let group = NSCollectionLayoutGroup.horizontal(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(166)
          ),
          subitem: item,
          count: 3
        )
        group.interItemSpacing = .fixed(8)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
          top: 0,
          leading: 16,
          bottom: 0,
          trailing: 16
        )
        section.contentInsets.bottom = 16
        section.interGroupSpacing = 8
        return section
      },
      configuration: configuration
    )
    return layout
  }
}

extension CGFloat {
  static let itemAspectRatio: CGFloat = 144/166
}
