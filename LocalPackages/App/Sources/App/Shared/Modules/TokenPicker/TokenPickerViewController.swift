import UIKit
import TKUIKit

final class TokenPickerViewController: GenericViewViewController<TokenPickerView>, TKBottomSheetScrollContentViewController {
  typealias Item = TKUIListItemCell.Configuration
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section,Item>
  
  enum Section {
    case tokens
  }
    
  private lazy var dataSource = createDataSource()
  
  private let viewModel: TokenPickerViewModel
  
  init(viewModel: TokenPickerViewModel) {
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
  
  // MARK: - TKPullCardScrollableContent
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  var didUpdateHeight: (() -> Void)?
  var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(title: .title(title: "Tokens", subtitle: nil))
  }
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    scrollView.contentSize.height
  }
}

private extension TokenPickerViewController {
  func setup() {
    customView.collectionView.delegate = self
    
    setupCollectionLayout()
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      guard let self else { return }
      let contentOffset = self.customView.collectionView.contentOffset
      self.dataSource.apply(snapshot, animatingDifferences: false, completion: {
        self.customView.collectionView.layoutIfNeeded()
        self.customView.collectionView.contentOffset = contentOffset
      })
      self.customView.collectionView.layoutIfNeeded()
      self.customView.collectionView.contentOffset = contentOffset
      self.didUpdateHeight?()
    }
    
    viewModel.didUpdateSelectedToken = { [weak self] index, isScroll in
      guard let index else { return }
      self?.customView.collectionView.selectItem(
        at: IndexPath(item: index, section: 0),
        animated: false,
        scrollPosition: isScroll ? [.centeredVertically] : []
      )
    }
  }
  
  func setupCollectionLayout() {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, environment in
      let item = NSCollectionLayoutItem(
        layoutSize: NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(76)
        )
      )
      
      let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                           heightDimension: .absolute(76)),
        subitems: [item]
      )

      let sectionLayout = NSCollectionLayoutSection(group: group)
      sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
      
      return sectionLayout
    }, configuration: configuration)
    
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
  }
  
  func createDataSource() -> DataSource {
    let itemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration>
    { [weak self, weak collectionView = self.customView.collectionView] cell, indexPath, identifier in
      guard let self else { return }
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
      cell.configure(configuration: identifier)
      cell.selectionAccessoryViews = self.createSelectionAccessoryViews()
    }
    
    return DataSource(collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
      return collectionView.dequeueConfiguredReusableCell(using: itemCellConfiguration, for: indexPath, item: itemIdentifier)
    }
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

extension TokenPickerViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    item.selectionClosure?()
  }
}
