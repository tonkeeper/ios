import UIKit
import TKUIKit

enum StakePoolDetailsSection {
  case details
  case links
}

final class StakePoolDetailsViewController: ModalViewController<StakePoolDetailsView, ModalNavigationBarView> {
  
  typealias CellRegistration<T> = UICollectionView.CellRegistration<T, T.Configuration> where T: TKCollectionViewNewCell & TKConfigurableView
  typealias Snapshot = NSDiffableDataSourceSnapshot<StakePoolDetailsSection, AnyHashable>
  
  // MARK: - List
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .details:
          return .detailsSection
        case .links:
          return .linksSection
        }
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var detailCellConfiguration: CellRegistration<TKUIListItemCell> = createDefaultCellRegistration()
  private lazy var linkCellConfiguration: CellRegistration<IconButtonCell> = createDefaultCellRegistration()
  
  // MARK: - Dependencies
  
  private let viewModel: StakePoolDetailsViewModel
  
  // MARK: - Init
  
  init(viewModel: StakePoolDetailsViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
  
  // MARK: - View Life cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupCollectionView()
    setupBindings()
    
    viewModel.viewDidLoad()
  }
  
  func setupCollectionView() {
    customView.collectionView.delegate = self
    customView.collectionView.showsVerticalScrollIndicator = false
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    
    customView.collectionView.register(
      TitleHeaderCollectionView.self,
      forSupplementaryViewOfKind: .titleHeaderElementKind,
      withReuseIdentifier: TitleHeaderCollectionView.reuseIdentifier
    )
    
    customView.collectionView.register(
      DescriptionFooterCollectionView.self,
      forSupplementaryViewOfKind: .descriptionFooterElementKind,
      withReuseIdentifier: DescriptionFooterCollectionView.reuseIdentifier
    )
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.details])
    snapshot.appendSections([.links])
    dataSource.apply(snapshot, animatingDifferences: false)
  }
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    
    customView.collectionView.contentInset.top = ModalNavigationBarView.defaultHeight
    
    customNavigationBarView.setupCenterBarItem(
      configuration: ModalNavigationBarView.BarItemConfiguration(
        view: customView.titleView
      )
    )
  }
}

// MARK: - Setup

private extension StakePoolDetailsViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.collectionView.backgroundColor = .Background.page
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didUpdateListItems = { [weak self] detailsItems, linksItems in
      guard let self else { return }
      var snapshot = dataSource.snapshot()
      snapshot.appendItems(detailsItems, toSection: .details)
      snapshot.appendItems(linksItems, toSection: .links)
      dataSource.apply(snapshot, animatingDifferences: false)
    }
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<StakePoolDetailsSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<StakePoolDetailsSection, AnyHashable>(
      collectionView: customView.collectionView) { [detailCellConfiguration, linkCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let cellConfiguration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: detailCellConfiguration, for: indexPath, item: cellConfiguration)
        case let cellConfiguration as IconButtonCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: linkCellConfiguration, for: indexPath, item: cellConfiguration)
        default: return nil
        }
      }
    
    dataSource.supplementaryViewProvider = { [weak dataSource] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let dataSource else { return nil }
      
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      switch section {
      case .details:
        let descriptionFooterView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: DescriptionFooterCollectionView.reuseIdentifier,
          for: indexPath
        ) as? DescriptionFooterCollectionView
        descriptionFooterView?.configure(
          model: DescriptionFooterCollectionView.Model(
            title: String.stakingWarningText.withTextStyle(.label3, color: .Text.tertiary)
          )
        )
        return descriptionFooterView
      case .links:
        let titleHeaderView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: TitleHeaderCollectionView.reuseIdentifier,
          for: indexPath
        ) as? TitleHeaderCollectionView
        titleHeaderView?.configure(
          model: TitleHeaderCollectionView.Model(
            title: String.linksHeaderTitle.withTextStyle(.h3, color: .Text.primary)
          )
        )
        return titleHeaderView
      }
    }
    
    return dataSource
  }
  
  func createDefaultCellRegistration<T>() -> CellRegistration<T> {
    return CellRegistration<T> { [weak self]
      cell, indexPath, itemIdentifier in
      cell.configure(configuration: itemIdentifier)
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
    }
  }
}

// MARK: - UICollectionViewDelegate

extension StakePoolDetailsViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    
    switch item {
    case let model as IconButtonCell.Configuration:
      model.selectionClosure?()
    default:
      break
    }
  }
  
  private func sectionIndex(of section: StakePoolDetailsSection) -> Int? {
    dataSource.snapshot().sectionIdentifiers.firstIndex(of: section)
  }
}

private extension NSCollectionLayoutSection {
  static var detailsSection: NSCollectionLayoutSection {
    let section = NSCollectionLayoutSection.createSection(cellHeight: .detailCellHeight)
    section.boundarySupplementaryItems = [.createDescriptionFooterItem()]
    return section
  }
  
  static var linksSection: NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .estimated(100),
      heightDimension: .absolute(.linkCellHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)

    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1),
      heightDimension: itemLayoutSize.heightDimension
    )
    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupLayoutSize, subitems: [item])
    group.interItemSpacing = .fixed(.linkCellInterGroupSpacing)
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .init(top: 0, leading: 16, bottom: 16, trailing: 16)
    section.interGroupSpacing = 8
    section.boundarySupplementaryItems = [.createTitleHeaderItem()]
    return section
  }
  
  static func createSection(cellHeight: CGFloat,
                          contentInsets: NSDirectionalEdgeInsets = .defaultSectionInsets) -> NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(cellHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(cellHeight)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = contentInsets
    return section
  }
}

private extension NSCollectionLayoutBoundarySupplementaryItem {
  static func createTitleHeaderItem() -> NSCollectionLayoutBoundarySupplementaryItem {
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(.titleHeaderHeight)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: .titleHeaderElementKind,
      alignment: .top
    )
    header.contentInsets = .init(top: 0, leading: 2, bottom: 0, trailing: 2)
    return header
  }
  
  static func createDescriptionFooterItem() -> NSCollectionLayoutBoundarySupplementaryItem {
    let footerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(.descriptionFooterHeight)
    )
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: .descriptionFooterElementKind,
      alignment: .bottom
    )
    footer.contentInsets = .init(top: 0, leading: 1, bottom: 0, trailing: 1)
    return footer
  }
}

private extension String {
  static let linksHeaderTitle = "Links"
  static let titleHeaderElementKind = "TitleHeaderElementKind"
  static let descriptionFooterElementKind = "DescriptionFooterElementKind"
  static let stakingWarningText = "Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience."
}

private extension CGFloat {
  static let titleHeaderHeight: CGFloat = 56
  static let descriptionFooterHeight: CGFloat = 60
  static let detailCellHeight: CGFloat = 44
  static let linkCellHeight: CGFloat = 36
  static let linkCellInterGroupSpacing: CGFloat = 8
}

private extension NSDirectionalEdgeInsets {
  static let defaultSectionInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
}
