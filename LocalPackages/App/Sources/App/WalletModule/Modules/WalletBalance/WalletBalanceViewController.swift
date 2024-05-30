import UIKit
import TKUIKit
import TKCoordinator

final class WalletBalanceViewController: GenericViewViewController<WalletBalanceView>, ScrollViewController, WalletContainerBalanceViewController {
  var didScroll: ((CGFloat) -> Void)?
  
  private let viewModel: WalletBalanceViewModel

  private lazy var layout: UICollectionViewCompositionalLayout = {
    
    let size = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(0)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: size,
      elementKind: .balanceHeaderElementKind,
      alignment: .top
    )
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    configuration.boundarySupplementaryItems = [header]
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [dataSource] sectionIndex, _ in
        let snapshot = dataSource.snapshot()
        switch snapshot.sectionIdentifiers[sectionIndex] {
        case .tonItems:
          return .balanceItemsSection
        case .jettonsItems:
          return .balanceItemsSection
        case .finishSetup:
          return .finishSetupItemsSection
        }
      },
      configuration: configuration
    )
    return layout
  }()
  
  private lazy var dataSource = createDataSource()
  private lazy var listItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
    cell, indexPath, itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in ip.item == 0 }
    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
      guard let collectionView = collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  }
  private lazy var finishSetupSectionHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListTitleView>>(
    elementKind: .finishSetupSectionHeaderElementKind) { [weak viewModel] supplementaryView, elementKind, indexPath in
      guard let viewModel else { return }
      supplementaryView.configure(model: viewModel.finishSetupSectionHeaderModel)
      supplementaryView.contentView.didTapButton = {
        viewModel.didTapFinishSetupButton()
      }
  }

  init(viewModel: WalletBalanceViewModel) {
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
    scrollToTop(animated: true)
  }
}

private extension WalletBalanceViewController {
  func setup() {
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
    customView.collectionView.register(
      TKReusableContainerView.self,
      forSupplementaryViewOfKind: .balanceHeaderElementKind,
      withReuseIdentifier: TKReusableContainerView.reuseIdentifier
    )
    customView.collectionView.delegate = self
    customView.collectionView.showsVerticalScrollIndicator = false
    
    var snapshot = dataSource.snapshot()
    snapshot.appendSections([.tonItems, .jettonsItems])
    dataSource.apply(snapshot,animatingDifferences: false)
  }
  
  func setupBindings() {
    viewModel.didChangeWallet = { [weak self] in
      self?.scrollToTop(animated: false)
    }
    
    viewModel.didUpdateHeader = { [weak customView] model in
      customView?.headerView.configure(model: model)
    }
    
    viewModel.didUpdateTonItems = { [weak dataSource] tonItems in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .tonItems))
      snapshot.appendItems(tonItems, toSection: .tonItems)
      dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    viewModel.didUpdateJettonItems = { [weak dataSource] jettonItems in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .jettonsItems))
      snapshot.appendItems(jettonItems, toSection: .jettonsItems)
      dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    viewModel.didUpdateFinishSetupItems = { [weak dataSource] items in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      snapshot.deleteSections([.finishSetup])
      
      if !items.isEmpty {
        snapshot.insertSections([.finishSetup], afterSection: .tonItems)
        snapshot.appendItems(items, toSection: .finishSetup)
      }
      
      dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    viewModel.didCopy = { configuration in
      ToastPresenter.showToast(configuration: configuration)
    }
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<WalletBalanceSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<WalletBalanceSection, AnyHashable>(
      collectionView: customView.collectionView) { [listItemCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let listCellConfiguration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(using: listItemCellConfiguration, for: indexPath, item: listCellConfiguration)
        default: return nil
        }
      }
    
    dataSource.supplementaryViewProvider = { [weak headerView = customView.headerView, finishSetupSectionHeaderRegistration] collectionView, kind, indexPath -> UICollectionReusableView? in
      switch kind {
      case String.balanceHeaderElementKind:
        let view = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind, 
          withReuseIdentifier: TKReusableContainerView.reuseIdentifier,
          for: indexPath
        ) as? TKReusableContainerView
        view?.setContentView(headerView)
        return view
      case String.finishSetupSectionHeaderElementKind:
        return collectionView.dequeueConfiguredReusableSupplementary(using: finishSetupSectionHeaderRegistration, for: indexPath)
      default: return nil
      }
    }
    
    return dataSource
  }
  
  func scrollToTop(animated: Bool = true) {
    guard customView.collectionView.contentOffset.y > customView.collectionView.adjustedContentInset.top else { return }
    customView.collectionView.setContentOffset(
      CGPoint(x: 0,
              y: -customView.collectionView.adjustedContentInset.top),
      animated: animated
    )
  }
}

extension WalletBalanceViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    switch item {
    case let model as TKUIListItemCell.Configuration:
      model.selectionClosure?()
    default:
      return
    }
  }
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    didScroll?(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
  }
}

private extension String {
  static let balanceHeaderElementKind = "BalanceHeaderElementKind"
  static let finishSetupSectionHeaderElementKind = "FinishSetupSectionHeaderElementKind"
}

private extension NSCollectionLayoutSection {
  static var balanceItemsSection: NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(76)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(76)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return section
  }
  
  static var finishSetupItemsSection: NSCollectionLayoutSection {
    let itemLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)
    
    let groupLayoutSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(76)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupLayoutSize,
      subitems: [item]
    )
    
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    
    let headerSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(48)
    )
    let header = NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: headerSize,
      elementKind: .finishSetupSectionHeaderElementKind,
      alignment: .top
    )
    section.boundarySupplementaryItems = [header]
    
    return section
  }
}
