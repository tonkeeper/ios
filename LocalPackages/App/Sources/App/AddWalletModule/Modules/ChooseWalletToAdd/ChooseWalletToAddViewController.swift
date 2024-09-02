import UIKit
import TKUIKit

final class ChooseWalletToAddViewController: GenericViewViewController<ChooseWalletToAddView>, KeyboardObserving {
  private let viewModel: ChooseWalletToAddViewModel
  
  init(viewModel: ChooseWalletToAddViewModel) {
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
  
  private func setup() {
    customView.collectionView.collectionViewLayout = layout
    customView.collectionView.allowsMultipleSelection = true
  }
  
  private func setupBindings() {
    viewModel.didUpdateHeaderViewModel = { [weak self] model in
      self?.customView.titleDescriptionView.configure(model: model)
    }
    viewModel.didUpdateOptionsSections = { [weak self] sections in
      var snapshot = NSDiffableDataSourceSnapshot<ChooseWalletToAddSection, ChooseWalletToAddItem>()
      snapshot.appendSections(sections)
      sections.forEach { section in
        snapshot.appendItems(section.items, toSection: section)
      }
      self?.dataSource.apply(snapshot, animatingDifferences: false) {
        let selectedItems = self?.viewModel.selectedItems
        selectedItems?.forEach {
          guard let index = snapshot.indexOfItem($0) else { return }
          let indexPath = IndexPath(item: index, section: 0)
          self?.customView.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
      }
    }
    viewModel.didUpdateModel = { [customView] in
      customView.configure(model: $0)
    }
  }

  private lazy var dataSource: UICollectionViewDiffableDataSource<ChooseWalletToAddSection, ChooseWalletToAddItem> = {
    let headerRegistration = UICollectionView.SupplementaryRegistration<TKReusableContainerView>(
      elementKind: .headerIdentifier) { [weak self] supplementaryView, elementKind, indexPath in
        supplementaryView.setContentView(self?.customView.titleDescriptionView)
      }
    let listCellRegistration = ListItemCellRegistration.registration(
      collectionView: customView.collectionView
    )
    let dataSource = UICollectionViewDiffableDataSource<ChooseWalletToAddSection, ChooseWalletToAddItem>(
      collectionView: customView.collectionView) { [weak viewModel] collectionView, indexPath, itemIdentifier in
        let cell = collectionView.dequeueConfiguredReusableCell(
          using: listCellRegistration, 
          for: indexPath,
          item: itemIdentifier.cellConfiguration
        )
        let tickAccessoryView = TKListItemTickAcessoryView()
        tickAccessoryView.isDisabled = !itemIdentifier.isSelectionEnable
        cell.defaultAccessoryViews = [tickAccessoryView]
        cell.isHiglightable = itemIdentifier.isSelectionEnable
        cell.onSelection = { isSelected in
          tickAccessoryView.isSelected = itemIdentifier.isSelectionEnable && isSelected
          if isSelected {
            viewModel?.didSelect(item: itemIdentifier)
          } else {
            viewModel?.didDeselect(item: itemIdentifier)
          }
        }
        return cell
      }
    dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
      switch elementKind {
      case .headerIdentifier:
        return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
      default: return nil
      }
    }
    return dataSource
  }()
  
  private var layout: UICollectionViewCompositionalLayout {
    let section = NSCollectionLayoutSection.listItemsSection
    section.contentInsets.top = 16
    section.contentInsets.bottom = 16
    section.contentInsets.leading = 32
    section.contentInsets.trailing = 32
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: .headerIdentifier,
      alignment: .top
    )
    configuration.boundarySupplementaryItems = [header]
    
    let layout = UICollectionViewCompositionalLayout(
      section: section,
      configuration: configuration
    )
    return layout
  }
}

private extension String {
  static let headerIdentifier = "HeaderIdentifier"
}
