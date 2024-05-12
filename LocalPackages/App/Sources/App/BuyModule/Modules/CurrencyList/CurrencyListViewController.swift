import UIKit
import TKUIKit

enum CurrencyListSection: Hashable {
  case currencyItems
}

final class CurrencyListViewController: ModalViewController<CurrencyListView, ModalNavigationBarView> {
  
  private typealias CellRegistration<T> = UICollectionView.CellRegistration<T, T.Configuration> where T: TKCollectionViewNewCell & TKConfigurableView
  
  // MARK: - Layout
  
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
        case .currencyItems:
          return .currencyItemsSection
        }
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var currencyCellConfiguration: CellRegistration<SelectionCollectionViewCell> = makeCellRegistration()
  
  private func makeCellRegistration<T>() -> CellRegistration<T> {
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
  
  private func createDataSource() -> UICollectionViewDiffableDataSource<CurrencyListSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<CurrencyListSection, AnyHashable>(
      collectionView: customView.collectionView) { [currencyCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let cellConfiguration as SelectionCollectionViewCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: currencyCellConfiguration, for: indexPath, item: cellConfiguration)
        default: return nil
        }
      }
    
    return dataSource
  }
  
  // MARK: - Dependencies
  
  private let viewModel: CurrencyListViewModel
  
  // MARK: - Init
  
  init(viewModel: CurrencyListViewModel) {
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
  
  override func setupNavigationBarView() {
    super.setupNavigationBarView()
    
    customView.collectionView.contentInset.top = ModalNavigationBarView.defaultHeight
    
    customNavigationBarView.setupCenterBarItem(configuration: .init(view: customView.titleView))
  }
}

// MARK: - Setup

private extension CurrencyListViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.collectionView.backgroundColor = .Background.page
  }
  
  func setupCollectionView() {
    customView.collectionView.delegate = self
    customView.collectionView.showsVerticalScrollIndicator = false
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.currencyItems])
    dataSource.apply(snapshot,animatingDifferences: false)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      
      let titleModel = ModalTitleView.Model(title: model.title)
      customView.titleView.configure(model: titleModel)
    }
    
    viewModel.didUpdateCurrencyListItems = { [weak self] currencyListItems, idToSelect in
      guard let self else { return }
      
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .currencyItems))
      snapshot.appendItems(currencyListItems, toSection: .currencyItems)
      dataSource.apply(snapshot,animatingDifferences: false)
      
      selectItemCell(withId: idToSelect, items: currencyListItems, inSection: .currencyItems, snapshot: snapshot)
    }
  }
  
  func selectItemCell<T: Hashable>(withId idToSelect: String,
                                   items: [SelectionCollectionViewCell.Configuration],
                                   inSection section: T,
                                   snapshot: NSDiffableDataSourceSnapshot<T, AnyHashable>) {
    guard let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: section),
          let rowIndex = items.firstIndex(where: { $0.id == idToSelect })
    else {
      return
    }
    
    let selectedIndexPath = IndexPath(row: rowIndex, section: sectionIndex)
    let selectionClosure = items[rowIndex].selectionClosure
    
    customView.collectionView.performBatchUpdates(nil) { [weak self] _ in
      self?.customView.collectionView.selectItem(at: selectedIndexPath, animated: false, scrollPosition: [])
      selectionClosure?()
    }
  }
}

// MARK: - UICollectionViewDelegate

extension CurrencyListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    
    guard let model = item as? SelectionCollectionViewCell.Configuration else { return }
    model.selectionClosure?()
  }
}

private extension NSCollectionLayoutSection {
  static var currencyItemsSection: NSCollectionLayoutSection {
    return makeSection(cellHeight: .currencyCellHeight)
  }
  
  static func makeSection(cellHeight: CGFloat,
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
  static let currencyCellHeight: CGFloat = 56
}
