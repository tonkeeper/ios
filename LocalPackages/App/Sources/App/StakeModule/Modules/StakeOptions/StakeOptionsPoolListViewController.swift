import UIKit
import TKUIKit

enum StakeOptionsPoolListSection {
  case pools
}

final class StakeOptionsPoolListViewController: ModalViewController<StakeOptionsView, ModalNavigationBarView> {
  
  typealias CellRegistration<T> = UICollectionView.CellRegistration<T, T.Configuration> where T: TKCollectionViewNewCell & TKConfigurableView
  typealias Snapshot = NSDiffableDataSourceSnapshot<StakeOptionsPoolListSection, AnyHashable>
  
  // MARK: - List
  
  private lazy var layout: UICollectionViewCompositionalLayout = {
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(.cellHeight)
    )
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .pools:
          return .poolsSection
        }
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var poolCellConfiguration: CellRegistration<SelectionCollectionViewCell> = createDefaultCellRegistration()
  
  // MARK: - Dependencies
  
  let selectedId: String
  let poolItems: [SelectionCollectionViewCell.Configuration]
  
  // MARK: - Init
  
  init(title: String, selectedId: String, poolItems: [SelectionCollectionViewCell.Configuration]) {
    self.poolItems = poolItems
    self.selectedId = selectedId
    super.init(nibName: nil, bundle: nil)
    self.customView.configure(
      model: StakeOptionsView.Model(
        title: ModalTitleView.Model(title: title)
      )
    )
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
  }
  
  func setupCollectionView() {
    customView.collectionView.delegate = self
    customView.collectionView.showsVerticalScrollIndicator = false
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.pools])
    snapshot.appendItems(poolItems)
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

private extension StakeOptionsPoolListViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.collectionView.backgroundColor = .Background.page
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<StakeOptionsPoolListSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<StakeOptionsPoolListSection, AnyHashable>(
      collectionView: customView.collectionView) { [poolCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let cellConfiguration as SelectionCollectionViewCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: poolCellConfiguration, for: indexPath, item: cellConfiguration)
        default: return nil
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

extension StakeOptionsPoolListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    
    switch item {
    case let model as SelectionCollectionViewCell.Configuration:
      model.selectionClosure?()
    default:
      break
    }
  }
  
  private func sectionIndex(of section: StakeOptionsPoolListSection) -> Int? {
    dataSource.snapshot().sectionIdentifiers.firstIndex(of: section)
  }
}

private extension NSCollectionLayoutSection {
  static var poolsSection: NSCollectionLayoutSection {
    return NSCollectionLayoutSection.createSection(cellHeight: .cellHeight)
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

private extension NSDirectionalEdgeInsets {
  static let defaultSectionInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
}

private extension CGFloat {
  static let cellHeight: CGFloat = 76
}
