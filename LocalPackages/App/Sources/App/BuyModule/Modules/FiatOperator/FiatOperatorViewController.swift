import UIKit
import TKUIKit

enum FiatOperatorSection: Hashable {
  case currencyPicker
  case fiatOperatorItems
}

final class FiatOperatorViewController: ModalViewController<FiatOperatorView, ModalNavigationBarView> {
  
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
        case .currencyPicker:
          return .currencyPickerSection
        case .fiatOperatorItems:
          return .fiatOperatorItemsSection
        }
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var currencyPickerCellConfiguration: CellRegistration<TKUIListItemCell> = makeCellRegistration()
  private lazy var fiatOperatorCellConfiguration: CellRegistration<RadioButtonCollectionViewCell> = makeCellRegistration()
  
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
  
  private func createDataSource() -> UICollectionViewDiffableDataSource<FiatOperatorSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<FiatOperatorSection, AnyHashable>(
      collectionView: customView.collectionView) { [fiatOperatorCellConfiguration, currencyPickerCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let cellConfiguration as RadioButtonCollectionViewCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: fiatOperatorCellConfiguration, for: indexPath, item: cellConfiguration)
        case let cellConfiguration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: currencyPickerCellConfiguration, for: indexPath, item: cellConfiguration)
        default: return nil
        }
      }
    
    return dataSource
  }
  
  // MARK: - Dependencies
  
  private let viewModel: FiatOperatorViewModel
  
  // MARK: - Init
  
  init(viewModel: FiatOperatorViewModel) {
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

private extension FiatOperatorViewController {
  func setup() {
    view.backgroundColor = .Background.page
    customView.collectionView.backgroundColor = .Background.page
  }
  
  func setupCollectionView() {
    customView.collectionView.delegate = self
    customView.collectionView.allowsMultipleSelection = true
    customView.collectionView.showsVerticalScrollIndicator = false
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.currencyPicker])
    snapshot.appendSections([.fiatOperatorItems])
    dataSource.apply(snapshot,animatingDifferences: false)
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
    
    viewModel.didUpdateCurrencyPickerItem = { [weak self] currencyPickerItem in
      guard let self else { return }
      
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .currencyPicker))
      snapshot.appendItems([currencyPickerItem], toSection: .currencyPicker)
      dataSource.apply(snapshot,animatingDifferences: false)
    }
    
    viewModel.didUpdateFiatOperatorItems = { [weak self] fiatOperatorItems in
      guard let self else { return }
      
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .fiatOperatorItems))
      snapshot.appendItems(fiatOperatorItems, toSection: .fiatOperatorItems)
      dataSource.apply(snapshot,animatingDifferences: false)
      
      selectFirstItemCell(snapshot: snapshot, items: fiatOperatorItems, inSection: .fiatOperatorItems)
    }
  }
  
  func selectFirstItemCell<T: Hashable>(snapshot: NSDiffableDataSourceSnapshot<T, AnyHashable>,
                                        items: [RadioButtonCollectionViewCell.Configuration],
                                        inSection section: T) {
    guard !items.isEmpty, let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: section) else {
      return
    }
    
    let selectedIndexPath = IndexPath(row: 0, section: sectionIndex)
    let selectedId = items[0].id
    
    customView.collectionView.performBatchUpdates(nil) { [weak self] _ in
      self?.customView.collectionView.selectItem(at: selectedIndexPath, animated: false, scrollPosition: .top)
      self?.viewModel.didSelectFiatOperatorId(selectedId)
    }
  }
}

// MARK: - UICollectionViewDelegate

extension FiatOperatorViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
    return false
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    // Handling simultaneous cell selection for currencyPicker and fiatOperatorItems sections
    // without this there will be multiple radio button selection
    if let fiatOperatorItemsSectionIndex = sectionIndex(of: .fiatOperatorItems), indexPath.section == fiatOperatorItemsSectionIndex {
      collectionView.indexPathsForSelectedItems?.lazy
        .filter { $0.section == fiatOperatorItemsSectionIndex }
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
    case .fiatOperatorItems:
      handleSelectionFiatOperatorItems(collectionView, at: indexPath, item: item)
    }
  }
  
  private func handleSelectionCurrencyPicker(_ collectionView: UICollectionView, at indexPath: IndexPath, item: AnyHashable) {
    collectionView.deselectItem(at: indexPath, animated: false)
    let currencyPickerModel = item as? TKUIListItemCell.Configuration
    currencyPickerModel?.selectionClosure?()
  }
  
  private func handleSelectionFiatOperatorItems(_ collectionView: UICollectionView, at indexPath: IndexPath, item: AnyHashable) {
    guard let model = item as? RadioButtonCollectionViewCell.Configuration else { return }
    viewModel.didSelectFiatOperatorId(model.id)
  }
  
  private func sectionIndex(of section: FiatOperatorSection) -> Int? {
    dataSource.snapshot().sectionIdentifiers.firstIndex(of: section)
  }
}

private extension NSCollectionLayoutSection {
  static var currencyPickerSection: NSCollectionLayoutSection {
    var contentInsets = NSDirectionalEdgeInsets.defaultSectionInsets
    contentInsets.bottom = 0
    return makeSection(cellHeight: .currencyPickerCellHeight, contentInsets: contentInsets)
  }
  
  static var fiatOperatorItemsSection: NSCollectionLayoutSection {
    return makeSection(cellHeight: .fiatOperatorCellHeight)
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
  static let defaultSectionInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
}

private extension CGFloat {
  static let currencyPickerCellHeight: CGFloat = 56
  static let fiatOperatorCellHeight: CGFloat = 76
}
