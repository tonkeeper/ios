import UIKit
import TKUIKit

final class BuySellListViewController: GenericViewViewController<BuySellListView>, TKBottomSheetScrollContentViewController {
  typealias Item = BuySellListItem
  typealias Section = BuySellListSection
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
  typealias CellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, String>
  typealias ButtonCellConfiguration = UICollectionView.CellRegistration<TKButtonCell, TKButtonCell.Model>
  
  private let viewModel: BuySellListViewModel
  
  // MARK: - TKBottomSheetScrollContentViewController
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    return TKUIKit.TKPullCardHeaderItem(title: .customView(segmentedControl))
  }
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    switch state {
    case .list:
      return scrollView.contentSize.height
    case .loading:
      return customView.loadingView
        .systemLayoutSizeFitting(CGSize(width: width, height: 0)).height
    }
  }
  
  private let segmentedControl = BuySellListSegmentedControl()
  
  // MARK: - State
  
  enum State {
    case loading
    case list
  }
  
  private var state: State = .loading {
    didSet {
      switch state {
      case .loading:
        customView.loadingView.loaderView.startAnimation()
        customView.collectionView.isHidden = true
        customView.loadingView.isHidden = false
      case .list:
        customView.loadingView.loaderView.stopAnimation()
        customView.loadingView.isHidden = true
        customView.collectionView.isHidden = false
      }
      didUpdateHeight?()
    }
  }
  
  // MARK: - List
  
  private lazy var layout = createLayout()
  private lazy var dataSource = createDataSource()
  
  // MARK: - Init
  
  init(viewModel: BuySellListViewModel) {
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
    setupViewEvents()
    viewModel.viewDidLoad()
  }
}

private extension BuySellListViewController {
  func setup() {
    state = .loading
    
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    customView.collectionView.register(
      BuyListSectionHeaderView.self,
      forSupplementaryViewOfKind: .sectionHeaderIdentifier,
      withReuseIdentifier: BuyListSectionHeaderView.reuseIdentifier
    )
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      guard let self else { return }
      self.dataSource.apply(snapshot, animatingDifferences: false, completion: {
        self.didUpdateHeight?()
      })
      self.didUpdateHeight?()
    }
    
    viewModel.didUpdateState = { [weak self] state in
      self?.state = state
    }
    
    viewModel.didUpdateSegmentedControl = { [weak self] model in
      if let model {
        self?.segmentedControl.isHidden = false
        self?.segmentedControl.configure(model: model)
      } else {
        self?.segmentedControl.isHidden = true
      }
    }
    
    viewModel.didUpdateHeaderLeftButton = { [weak self] model in
      guard let self else { return }
      let headerItem = TKUIKit.TKPullCardHeaderItem(
        title: .customView(
          self.segmentedControl
        ),
        leftButton: model
      )
      didUpdatePullCardHeaderItem?(headerItem)
    }
  }
  
  func setupViewEvents() {
    segmentedControl.didSelectTab = { [weak self] index in
      self?.viewModel.selectTab(index: index)
    }
  }
  
  func createDataSource() -> DataSource {
    let cellConfiguration = CellConfiguration { 
      [weak viewModel, weak collectionView = self.customView.collectionView] cell, indexPath, identifier in
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
      guard let model = viewModel?.getCellConfiguration(identifier: identifier) as? TKUIListItemCell.Configuration else { return }
      cell.configure(configuration: model)
    }
    let buttonCellConfiguration = UICollectionView.CellRegistration<TKButtonCell, TKButtonCell.Model> {
      cell, indexPath, identifier in
      cell.configure(model: identifier)
    }
    let dataSource = DataSource(collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
      switch itemIdentifier {
      case .item(let identifier):
        collectionView.dequeueConfiguredReusableCell(using: cellConfiguration, for: indexPath, item: identifier)
      case .button(let buttonModel):
        collectionView.dequeueConfiguredReusableCell(using: buttonCellConfiguration, for: indexPath, item: buttonModel)
      }
    }
    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
      let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
      switch section {
      case let .items(_, title, assets):
        let model = BuyListSectionHeaderView.Model(
          titleViewModel: TKListTitleView.Model(title: title, textStyle: .h3),
          assetsViewModel: BuyListSectionHeaderAssetsView.Model(
            assets: assets.map { BuyListSectionHeaderAssetsView.Model.Asset(image: $0) }
          )
        )
        let view = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: BuyListSectionHeaderView.reuseIdentifier,
          for: indexPath)
        (view as? BuyListSectionHeaderView)?.configure(model: model)
        return view
      default:
        return nil
      }
    }
    
    return dataSource
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { [dataSource] sectionIndex, _ in
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[sectionIndex]
      
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
      
      switch section {
      case .items:
        let headerSize = NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(56)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
          layoutSize: headerSize,
          elementKind: .sectionHeaderIdentifier,
          alignment: .top
        )
        layoutSection.boundarySupplementaryItems = [header]
      default:
        break
      }
      
      return layoutSection
    }, configuration: configuration)
    
    return layout
  }
}

extension BuySellListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    viewModel.selecteItem(item)
  }
}

private extension String {
  static let sectionHeaderIdentifier = "SectionHeaderIdentifier"
}
