import UIKit
import TKUIKit

enum BuySellOperatorSection: Hashable {
  case currencyPicker
  case operatorItems
  case shimmer
}

final class BuySellOperatorViewController: ModalViewController<BuySellOperatorView, ModalNavigationBarView> {
  
  typealias OperatorShimmerView = TKCollectionViewSupplementaryContainerView<BuySellOperatorShimmerView>
  typealias CellRegistration<T> = UICollectionView.CellRegistration<T, T.Configuration> where T: TKCollectionViewNewCell & TKConfigurableView
  
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
        case .currencyPicker:
          return .currencyPickerSection
        case .operatorItems:
          return .operatorItemsSection
        case .shimmer:
          return .shimmerSection
        }
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var currencyPickerCellConfiguration: CellRegistration<TKUIListItemCell> = createDefaultCellRegistration()
  private lazy var operatorCellConfiguration: CellRegistration<SelectionCollectionViewCell> = createDefaultCellRegistration()
  
  // MARK: - Dependencies
  
  private let viewModel: BuySellOperatorViewModel
  
  // MARK: - Init
  
  init(viewModel: BuySellOperatorViewModel) {
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

private extension BuySellOperatorViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.collectionView.backgroundColor = .Background.page
  }
  
  func setupCollectionView() {
    customView.collectionView.delegate = self
    customView.collectionView.allowsMultipleSelection = true
    customView.collectionView.showsVerticalScrollIndicator = false
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    
    customView.collectionView.register(
      OperatorShimmerView.self,
      forSupplementaryViewOfKind: .shimmerSectionFooterElementKind,
      withReuseIdentifier: OperatorShimmerView.reuseIdentifier
    )
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.shimmer])
    snapshot.appendSections([.currencyPicker])
    snapshot.appendSections([.operatorItems])
    dataSource.apply(snapshot, animatingDifferences: false)
  }
  
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let customView = self?.customView else { return }
      
      let titleViewModel = ModalTitleView.Model(title: model.title, description: model.description)
      customView.titleView.configure(model: titleViewModel)
      
      customView.continueButton.configuration.content = TKButton.Configuration.Content(title: .plainString(model.button.title))
      customView.continueButton.configuration.isEnabled = model.button.isEnabled
      customView.continueButton.configuration.showsLoader = model.button.isActivity
      customView.continueButton.configuration.action = model.button.action
    }
    
    viewModel.didLoadListItems = { [weak self] currencyPickerItem, fiatOperatorItems in
      guard let self else { return }
      
      var snapshot = dataSource.snapshot()
      snapshot.deleteSections([.shimmer])
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .currencyPicker))
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .operatorItems))
      snapshot.appendItems([currencyPickerItem], toSection: .currencyPicker)
      snapshot.appendItems(fiatOperatorItems, toSection: .operatorItems)
      dataSource.apply(snapshot, animatingDifferences: true)
      
      selectFirstItemCell(snapshot: snapshot, items: fiatOperatorItems, inSection: .operatorItems)
    }
    
    viewModel.didUpdateCurrencyPickerItem = { [weak self] currencyPickerItem in
      guard let self else { return }
      
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .currencyPicker))
      snapshot.appendItems([currencyPickerItem], toSection: .currencyPicker)
      dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    viewModel.didUpdateFiatOperatorItems = { [weak self] buySellOperatorItems in
      guard let self else { return }
      
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .operatorItems))
      snapshot.appendItems(buySellOperatorItems, toSection: .operatorItems)
      dataSource.apply(snapshot, animatingDifferences: false)
      
      selectFirstItemCell(snapshot: snapshot, items: buySellOperatorItems, inSection: .operatorItems)
    }
  }
  
  func selectFirstItemCell<T: Hashable>(snapshot: NSDiffableDataSourceSnapshot<T, AnyHashable>,
                                        items: [SelectionCollectionViewCell.Configuration],
                                        inSection section: T) {
    guard !items.isEmpty, let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: section) else {
      return
    }
    
    let selectedIndexPath = IndexPath(row: 0, section: sectionIndex)
    let selectionClosure = items[0].selectionClosure
    
    customView.collectionView.performBatchUpdates(nil) { [weak self] _ in
      self?.customView.collectionView.selectItem(at: selectedIndexPath, animated: false, scrollPosition: .top)
      selectionClosure?()
    }
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<BuySellOperatorSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<BuySellOperatorSection, AnyHashable>(
      collectionView: customView.collectionView) { [operatorCellConfiguration, currencyPickerCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let cellConfiguration as SelectionCollectionViewCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: operatorCellConfiguration, for: indexPath, item: cellConfiguration)
        case let cellConfiguration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: currencyPickerCellConfiguration, for: indexPath, item: cellConfiguration)
        default: return nil
        }
      }
    
    dataSource.supplementaryViewProvider = { [weak dataSource] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let dataSource else { return nil }
      
      let snapshot = dataSource.snapshot()
      let section = snapshot.sectionIdentifiers[indexPath.section]
      switch section {
      case .shimmer:
        let shimmerView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: OperatorShimmerView.reuseIdentifier,
          for: indexPath
        )
        (shimmerView as? OperatorShimmerView)?.contentView.startAnimation()
        return shimmerView
      default:
        return nil
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

extension BuySellOperatorViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
    return false
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    // Handling simultaneous cell selection for currencyPicker and operatorItems sections
    // without this there will be multiple radio button selection
    if let operatorItemsSectionIndex = sectionIndex(of: .operatorItems), indexPath.section == operatorItemsSectionIndex {
      collectionView.indexPathsForSelectedItems?.lazy
        .filter { $0.section == operatorItemsSectionIndex }
        .forEach { collectionView.deselectItem(at: $0, animated: false) }
    }

    return true
  }
  
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    
    switch section {
    case .currencyPicker:
      handleSelectionCurrencyPicker(collectionView, at: indexPath, item: item)
    case .operatorItems:
      handleSelectionOperatorItems(collectionView, at: indexPath, item: item)
    case .shimmer:
      break
    }
  }
  
  private func handleSelectionCurrencyPicker(_ collectionView: UICollectionView, at indexPath: IndexPath, item: AnyHashable) {
    collectionView.deselectItem(at: indexPath, animated: false)
    let currencyPickerModel = item as? TKUIListItemCell.Configuration
    currencyPickerModel?.selectionClosure?()
  }
  
  private func handleSelectionOperatorItems(_ collectionView: UICollectionView, at indexPath: IndexPath, item: AnyHashable) {
    guard let model = item as? SelectionCollectionViewCell.Configuration else { return }
    model.selectionClosure?()
  }
  
  private func sectionIndex(of section: BuySellOperatorSection) -> Int? {
    dataSource.snapshot().sectionIdentifiers.firstIndex(of: section)
  }
}

private extension NSCollectionLayoutSection {
  static var currencyPickerSection: NSCollectionLayoutSection {
    var contentInsets = NSDirectionalEdgeInsets.defaultSectionInsets
    contentInsets.top = 0
    contentInsets.bottom = 0
    return createSection(cellHeight: .currencyPickerCellHeight, contentInsets: contentInsets)
  }
  
  static var operatorItemsSection: NSCollectionLayoutSection {
    return createSection(cellHeight: .operatorCellHeight)
  }
  
  static var shimmerSection: NSCollectionLayoutSection {
    let section = NSCollectionLayoutSection.createSection(
      cellHeight: 100,
      contentInsets: .init(top: 0, leading: 16, bottom: 0, trailing: 16)
    )
    let footerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(100)
    )
    let footer = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: footerSize,
      elementKind: .shimmerSectionFooterElementKind,
      alignment: .bottom
    )
    section.boundarySupplementaryItems = [footer]
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

private extension String {
  static let shimmerSectionFooterElementKind = "ShimmerSectionFooterElementKind"
}

private extension NSDirectionalEdgeInsets {
  static let defaultSectionInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
}

private extension CGFloat {
  static let currencyPickerCellHeight: CGFloat = 56
  static let operatorCellHeight: CGFloat = 76
}
