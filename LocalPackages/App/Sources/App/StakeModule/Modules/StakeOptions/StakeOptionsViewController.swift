import UIKit
import TKUIKit

struct StakeOptionsSelectedItem {
  let id: String
  let section: StakeOptionsSection
}

enum StakeOptionsSection {
  case liquidStaking
  case other
}

final class StakeOptionsViewController: ModalViewController<StakeOptionsView, ModalNavigationBarView> {
  
  typealias CellRegistration<T> = UICollectionView.CellRegistration<T, T.Configuration> where T: TKCollectionViewNewCell & TKConfigurableView
  typealias Snapshot = NSDiffableDataSourceSnapshot<StakeOptionsSection, AnyHashable>
  
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
        case .liquidStaking:
          return .liquidStakingSection
        case .other:
          return .otherSection
        }
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var liquidStakingCellConfiguration: CellRegistration<SelectionCollectionViewCell> = createDefaultCellRegistration()
  private lazy var otherCellConfiguration: CellRegistration<TKUIListItemCell> = createDefaultCellRegistration()
  
  // MARK: - Dependencies
  
  private let viewModel: StakeOptionsViewModel
  
  // MARK: - Init
  
  init(viewModel: StakeOptionsViewModel) {
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
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.liquidStaking])
    snapshot.appendSections([.other])
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

private extension StakeOptionsViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.collectionView.backgroundColor = .Background.page
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak customView] model in
      customView?.configure(model: model)
    }
    
    viewModel.didUpdatePoolList = { [weak self] liquidStakingItems, otherItems in
      guard let self else { return }
      var snapshot = dataSource.snapshot()
      snapshot.appendItems(liquidStakingItems, toSection: .liquidStaking)
      snapshot.appendItems(otherItems, toSection: .other)
      dataSource.apply(snapshot, animatingDifferences: false)
    }
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<StakeOptionsSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<StakeOptionsSection, AnyHashable>(
      collectionView: customView.collectionView) { [liquidStakingCellConfiguration, otherCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let cellConfiguration as SelectionCollectionViewCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: liquidStakingCellConfiguration, for: indexPath, item: cellConfiguration)
        case let cellConfiguration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: otherCellConfiguration, for: indexPath, item: cellConfiguration)
        default: return nil
        }
      }
    
    dataSource.supplementaryViewProvider = { [weak dataSource] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let dataSource else { return nil }
      
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      switch section {
      case .liquidStaking:
        let titleHeaderView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: TitleHeaderCollectionView.reuseIdentifier,
          for: indexPath
        ) as? TitleHeaderCollectionView
        titleHeaderView?.configure(
          model: TitleHeaderCollectionView.Model(
            title: String.liquidStakingHeaderTitle.withTextStyle(.h3, color: .Text.primary)
          )
        )
        return titleHeaderView
      case .other:
        let titleHeaderView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: TitleHeaderCollectionView.reuseIdentifier,
          for: indexPath
        ) as? TitleHeaderCollectionView
        titleHeaderView?.configure(
          model: TitleHeaderCollectionView.Model(
            title: String.otherHeaderTitle.withTextStyle(.h3, color: .Text.primary)
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

extension StakeOptionsViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    
    switch item {
    case let model as SelectionCollectionViewCell.Configuration:
      model.selectionClosure?()
    case let model as TKUIListItemCell.Configuration:
      model.selectionClosure?()
    default:
      break
    }
  }
  
  private func sectionIndex(of section: StakeOptionsSection) -> Int? {
    dataSource.snapshot().sectionIdentifiers.firstIndex(of: section)
  }
}

private extension NSCollectionLayoutSection {
  static var liquidStakingSection: NSCollectionLayoutSection {
    let section = NSCollectionLayoutSection.createSection(cellHeight: .cellHeight)
    section.boundarySupplementaryItems = [.createTitleHeaderItem()]
    return section
  }
  
  static var otherSection: NSCollectionLayoutSection {
    let section = NSCollectionLayoutSection.createSection(cellHeight: .cellHeight)
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
}

private extension String {
  static let liquidStakingHeaderTitle = "Liquid Staking"
  static let otherHeaderTitle = "Other"
  static let titleHeaderElementKind = "TitleHeaderElementKind"
}

private extension NSDirectionalEdgeInsets {
  static let defaultSectionInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
}

private extension CGFloat {
  static let titleHeaderHeight: CGFloat = 56
  static let cellHeight: CGFloat = 96
}
