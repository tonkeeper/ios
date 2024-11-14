import UIKit
import TKUIKit

final class StakingListViewController: GenericViewViewController<StakingListView> {
  typealias SectionHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListTitleView>>
  
  private let viewModel: StakingListViewModel
  
  private lazy var layout = createLayout()
  private lazy var dataSource = createDataSource()
  
  init(viewModel: StakingListViewModel) {
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
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    customView.navigationBar.layoutIfNeeded()
    customView.collectionView.contentInset.top = customView.navigationBar.bounds.height
    customView.collectionView.contentInset.bottom = customView.safeAreaInsets.bottom + 16
  }
}

private extension StakingListViewController {
  func setup() {
    setupNavigationBar()
    
    customView.titleView.configure(
      model: TKUINavigationBarTitleView.Model(
        title: viewModel.title.withTextStyle(
          .h3,
          color: .Text.primary,
          alignment: .center,
          lineBreakMode: .byTruncatingTail
        )
      )
    )
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.delegate = self
  }
  
  private func setupNavigationBar() {
    guard let navigationController,
          !navigationController.viewControllers.isEmpty else {
      return
    }
    if navigationController.viewControllers.count > 1 {
      customView.navigationBar.leftViews = [
        TKUINavigationBar.createBackButton {
          navigationController.popViewController(animated: true)
        }
      ]
    }
    
    customView.navigationBar.rightViews = [
      TKUINavigationBar.createCloseButton { [weak self] in
        self?.viewModel.didTapCloseButton()
      }
    ]
  }
  
  func setupBindings() {
    viewModel.didUpdateSnapshot = { [weak self] snapshot in
      self?.dataSource.apply(snapshot, animatingDifferences: false)
    }
  }
  
  func createLayout() -> UICollectionViewCompositionalLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout { [dataSource] sectionIndex, _ in
      let snapshot = dataSource.snapshot()
      let snapshotSection = snapshot.sectionIdentifiers[sectionIndex]
      
      let itemLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(.itemHeigth)
      )
      let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
      
      let groupLayoutSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(.itemHeigth)
      )
      let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: groupLayoutSize,
        subitems: [item]
      )
      
      let section = NSCollectionLayoutSection(group: group)
      section.contentInsets = NSDirectionalEdgeInsets(
        top: 0,
        leading: 16,
        bottom: 0,
        trailing: 16
      )
      
      if snapshotSection.title != nil {
        let headerSize = NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(48)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
          layoutSize: headerSize,
          elementKind: .sectionHeaderElementKind,
          alignment: .top
        )
        section.boundarySupplementaryItems = [header]
      }
      
      return section
    }
    return layout
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<StakingListCollectionSection, TKUIListItemCell.Configuration> {
    let cellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self] cell, indexPath, identifier in
      guard let self else { return }
      cell.configure(configuration: identifier)
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { [weak collectionView = self.customView.collectionView] ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
    }
    let dataSource = UICollectionViewDiffableDataSource<StakingListCollectionSection, TKUIListItemCell.Configuration>(collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
      let cell = collectionView.dequeueConfiguredReusableCell(using: cellConfiguration, for: indexPath, item: itemIdentifier)
      return cell
    }
    
    let sectionHeaderRegistration = SectionHeaderRegistration(elementKind: .sectionHeaderElementKind) { [weak self] supplementaryView, elementKind, indexPath in
      guard let self else { return }
      let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
      supplementaryView.configure(model: TKListTitleView.Model(title: section.title, textStyle: .h3))
    }
    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in
      switch kind {
      case .sectionHeaderElementKind:
        return collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderRegistration, for: indexPath)
      default: return nil
      }
    }
    
    return dataSource
  }
}

extension StakingListViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    item.selectionClosure?()
  }
}

private extension CGFloat {
  static let itemHeigth: CGFloat = 96
}

private extension String {
  static let sectionHeaderElementKind = "SectionHeaderElementKind"
}
