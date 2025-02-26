import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class BrowserExploreViewController: GenericViewViewController<BrowserExploreView>, ScrollViewController {
  
  typealias DataSource = UICollectionViewDiffableDataSource<BrowserExploreSection, AnyHashable>
  private let viewModel: BrowserExploreViewModel
  
  private let featuredView = BrowserExploreFeaturedView()
  
  private lazy var dataSource = createDataSource()
  
  var isHorizontalScrollingEnabled = false
  
  private lazy var listItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in
      return ip.item % 3 == 0
    }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView else { return false }
      return (ip.item + 1) % 3 == 0 || ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  }
  
  lazy var layout = createLayout()
  
  private lazy var sectionHeaderRegistration = UICollectionView.SupplementaryRegistration<BrowserExploreSectionHeaderView>(
    elementKind: BrowserExploreSectionHeaderView.reuseIdentifier) { _, _, _ in }
  
  
  init(viewModel: BrowserExploreViewModel) {
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
  
  func setListContentInsets(_ insets: UIEdgeInsets) {
    customView.topInset = insets.top
    customView.collectionView.contentInset = insets
  }
}

extension BrowserExploreViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let item = dataSource
      .snapshot()
      .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case let listItem as BrowserAppCollectionViewCell.Configuration:
      listItem.selectionClosure?()
    default: break
    }
  }
}

// MARK: - Private

private extension BrowserExploreViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
    customView.collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "ContainerCell")
    
    featuredView.didSelectApp = { [weak self] dapp in
      self?.viewModel.selectFeaturedApp(dapp: dapp)
    }
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    viewModel.didUpdateFeaturedItems = { [weak self] dapps in
      if dapps.isEmpty {
        self?.featuredView.isHidden = false
      } else {
        self?.featuredView.isHidden = false
        self?.featuredView.dapps = dapps
      }
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
      case let .regular(title,_ ,_):
        return regularSectionLayout(
          snapshot: snapshot,
          hasTitle: title != nil,
          section: section,
          environment: environment
        )
      case .featured:
        return featuredSectionLayout(environment: environment)
      }
    }, configuration: configuration)
    
    return layout
  }
  
  func regularSectionLayout(snapshot: NSDiffableDataSourceSnapshot<BrowserExploreSection, AnyHashable>,
                            hasTitle: Bool,
                            section: BrowserExploreSection,
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
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .init(top: 10, leading: 12, bottom: 16, trailing: 12)
    
    if hasTitle {
      let headerSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(56)
      )
      let header = NSCollectionLayoutBoundarySupplementaryItem(
        layoutSize: headerSize,
        elementKind: BrowserExploreSectionHeaderView.reuseIdentifier,
        alignment: .top
      )
      section.boundarySupplementaryItems = [header]
    }
    
    return section
  }
  
  func featuredSectionLayout(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .fractionalWidth(0.46)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    item.contentInsets = .init(top: 0, leading: 4, bottom: 0, trailing: 4)
    
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(50)
    )
    
    let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    return section
  }
  
  func createDataSource() -> DataSource {
    let connectedAppCellConfiguration = UICollectionView.CellRegistration<BrowserAppCollectionViewCell, BrowserAppCollectionViewCell.Configuration> { cell, indexPath, itemIdentifier in
      cell.configure(configuration: itemIdentifier)
    }
    
    let dataSource = DataSource(collectionView: customView.collectionView) { [featuredView] collectionView, indexPath, itemIdentifier in
      switch itemIdentifier {
      case let item as BrowserAppCollectionViewCell.Configuration:
        return collectionView.dequeueConfiguredReusableCell(using: connectedAppCellConfiguration, for: indexPath, item: item)
      case _ as BrowserExploreFeatureSectionItem:
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ContainerCell", for: indexPath)
        cell.contentView.addSubview(featuredView)
        featuredView.snp.makeConstraints { make in
          make.edges.equalTo(cell.contentView)
        }
        return cell
      default: return nil
      }
    }
    
    dataSource.supplementaryViewProvider = {
      [weak self, sectionHeaderRegistration, dataSource] collectionView, elementKind, indexPath in
      guard let self else { return nil }
      switch elementKind {
      case BrowserExploreSectionHeaderView.reuseIdentifier:
        let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
        switch section {
        case let .regular(title, hasAll, _):
          let sectionHeader = collectionView.dequeueConfiguredReusableSupplementary(
            using: sectionHeaderRegistration,
            for: indexPath
          )
          
          sectionHeader.configure(model: BrowserExploreSectionHeaderView.Model(
            title: title ?? "",
            isAllHidden: !hasAll,
            allTapAction: { [weak self] in
              self?.viewModel.didSelectCategoryAll(index: indexPath.section)
            })
          )
          return sectionHeader
        case .featured:
          return nil
        }
      default:
        return nil
      }
    }
    
    return dataSource
  }
}
