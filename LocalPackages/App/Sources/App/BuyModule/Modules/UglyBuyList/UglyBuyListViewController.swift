import UIKit
import TKUIKit
import TKLocalize

class UglyBuyListViewController: GenericViewViewController<UglyBuyListView>, TKBottomSheetScrollContentViewController {
  
  // MARK: - Module

  private let viewModel: UglyBuyListViewModel
  
  // MARK: - TKBottomSheetScrollContentViewController
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(title: .title(title: TKLocales.UglyBuyList.buy, subtitle: nil))
  }
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    scrollView.contentSize.height
  }
  
  // MARK: - List
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: size,
      elementKind: .headerKind,
      alignment: .top
    )
    configuration.boundarySupplementaryItems = [header]
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .items:
          return .itemSection
        }
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var listItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in ip.item == 0 }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  }
  
  // MARK: - Init

  init(viewModel: UglyBuyListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    viewModel.viewDidLoad()
  }
}

// MARK: - Private

private extension UglyBuyListViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    
    customView.collectionView.register(
      UglyBuyListHeaderView.self,
      forSupplementaryViewOfKind: .headerKind,
      withReuseIdentifier: UglyBuyListHeaderView.reuseIdentifier
    )
    
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false, completion: {
        self?.didUpdateHeight?()
      })
    }
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<UglyBuyListSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<UglyBuyListSection, AnyHashable>(
      collectionView: customView.collectionView) { [listItemCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let listCellConfiguration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: listItemCellConfiguration, for: indexPath, item: listCellConfiguration)
        default: return nil
        }
      }
  
    dataSource.supplementaryViewProvider = {
      collectionView,
      kind,
      indexPath in
      switch kind {
      case .headerKind:
        return collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: UglyBuyListHeaderView.reuseIdentifier,
          for: indexPath
        )
      default:
        return nil
      }
    }
    
    return dataSource
  }
}

extension UglyBuyListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    switch item {
    case let model as TKUIListItemCell.Configuration:
      model.selectionClosure?()
    default:
      return
    }
  }
}

private extension NSCollectionLayoutSection {
  static var itemSection: NSCollectionLayoutSection {
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
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
  
    return section
  }
}

private extension String {
  static let headerKind = "HeaderKind"
}
