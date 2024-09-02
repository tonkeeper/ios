import UIKit
import TKUIKit

final class AddWalletOptionPickerViewController: GenericViewViewController<AddWalletOptionPickerView>, TKBottomSheetScrollContentViewController {
  private let viewModel: AddWalletOptionPickerViewModel

  init(viewModel: AddWalletOptionPickerViewModel) {
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
  
  // MARK: - TKBottomSheetScrollContentViewController
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  var didUpdateHeight: (() -> Void)?
  var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    scrollView.contentSize.height + view.safeAreaInsets.bottom
  }
  
  private func setup() {
    customView.collectionView.collectionViewLayout = layout
    customView.collectionView.delegate = self
  }
  
  private func setupBindings() {
    viewModel.didUpdateHeaderViewModel = { [weak self] model in
      self?.customView.titleDescriptionView.configure(model: model)
    }
    viewModel.didUpdateOptionsSections = { [weak self] sections in
      guard let self else { return }
      var snapshot = NSDiffableDataSourceSnapshot<AddWalletOptionPickerSection, AddWalletOptionPickerItem>()
      snapshot.appendSections(sections)
      sections.forEach { section in
        snapshot.appendItems([section.item], toSection: section)
      }
      self.dataSource.apply(snapshot, animatingDifferences: false)
    }
  }
  
  private lazy var dataSource: UICollectionViewDiffableDataSource<AddWalletOptionPickerSection, AddWalletOptionPickerItem> = {
    let headerRegistration = UICollectionView.SupplementaryRegistration<TKReusableContainerView>(
      elementKind: .headerIdentifier) { [weak self] supplementaryView, elementKind, indexPath in
        supplementaryView.setContentView(self?.customView.titleDescriptionView)
      }
    let listCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
    let dataSource = UICollectionViewDiffableDataSource<AddWalletOptionPickerSection, AddWalletOptionPickerItem>(
      collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
        let cell = collectionView.dequeueConfiguredReusableCell(using: listCellRegistration, for: indexPath, item: itemIdentifier.cellConfiguration)
        let accessoryView = TKListItemIconAccessoryView()
        accessoryView.configuration = .chevron
        cell.defaultAccessoryViews = [accessoryView]
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
    let widthDimension: NSCollectionLayoutDimension = .fractionalWidth(1.0)
    let heightDimension: NSCollectionLayoutDimension = .estimated(76)
    
    let itemSize = NSCollectionLayoutSize(
      widthDimension: widthDimension,
      heightDimension: heightDimension
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
  
    let groupSize = NSCollectionLayoutSize(
      widthDimension: widthDimension,
      heightDimension: heightDimension
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0, leading: 32, bottom: 16, trailing: 32
    )
    
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

extension AddWalletOptionPickerViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    viewModel.didSelectItem(item)
  }
}

private extension String {
  static let headerIdentifier = "HeaderIdentifier"
}
