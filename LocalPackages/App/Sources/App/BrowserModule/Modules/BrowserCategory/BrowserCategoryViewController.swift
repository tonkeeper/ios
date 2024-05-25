import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class BrowserCategoryViewController: GenericViewViewController<BrowserCategoryView> {
  
  typealias DataSource = UICollectionViewDiffableDataSource<BrowserCategorySection, AnyHashable>
  private let viewModel: BrowserCategoryViewModel
  
  private lazy var dataSource = createDataSource()
  
  private lazy var listItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in
      return ip.item == 0
    }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  }
  
  init(viewModel: BrowserCategoryViewModel) {
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
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(false, animated: true)
  }

  func setListContentInsets(_ insets: UIEdgeInsets) {
    customView.collectionView.contentInset = insets
  }
}

extension BrowserCategoryViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let item = dataSource
      .snapshot()
      .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case let listItem as TKUIListItemCell.Configuration:
      listItem.selectionClosure?()
    default: break
    }
  }
}

// MARK: - Private

private extension BrowserCategoryViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(createLayout(), animated: false)
    customView.collectionView.delegate = self
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    viewModel.didUpdateTitle = { [weak self] title in
      self?.title = title
    }
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let layout = UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
      
      let itemSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1),
        heightDimension: .absolute(84)
      )
      let item = NSCollectionLayoutItem(layoutSize: itemSize)
      
      let groupSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(84)
      )
      
      let group: NSCollectionLayoutGroup
    
      if #available(iOS 16.0, *) {
        group = NSCollectionLayoutGroup.horizontal(
          layoutSize: groupSize,
          repeatingSubitem: item,
          count: 1
        )
      } else {
        group = NSCollectionLayoutGroup.horizontal(
          layoutSize: groupSize,
          subitem: item,
          count: 1
        )
      }
      
      let section = NSCollectionLayoutSection(group: group)
      section.contentInsets = .init(top: 10, leading: 16, bottom: 16, trailing: 16)
      return section

    }
    return layout
  }
  
  func createDataSource() -> DataSource {
    let dataSource = DataSource(collectionView: customView.collectionView) { [listItemCellConfiguration] collectionView, indexPath, itemIdentifier in
      switch itemIdentifier {
      case let listCellConfiguration as TKUIListItemCell.Configuration:
        return collectionView.dequeueConfiguredReusableCell(using: listItemCellConfiguration, for: indexPath, item: listCellConfiguration)
      default: return nil
      }
    }
    
    return dataSource
  }
}

