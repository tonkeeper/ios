import UIKit
import TKUIKit
import TKCoordinator

final class WalletBalanceViewController: GenericViewViewController<WalletBalanceView>, ScrollViewController, WalletContainerBalanceViewController {
  typealias Section = WalletBalanceSection
  typealias Item = AnyHashable
  typealias DataSource = UICollectionViewDiffableDataSource<WalletBalanceSection, Item>
  typealias Snapshot = NSDiffableDataSourceSnapshot<WalletBalanceSection, Item>
  typealias BalanceItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, WalletBalanceItem>
  typealias SetupSectionHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListTitleView>>
  
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
        return WalletBalanceViewController.createLayoutSection(section: snapshot.sectionIdentifiers[sectionIndex])
      },
      configuration: configuration
    )
    return layout
  }()
  
  private lazy var dataSource: DataSource = createDataSource()
//  private lazy var listItemCellConfiguration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration> { [weak self]
//    cell, indexPath, itemIdentifier in
//    cell.configure(configuration: itemIdentifier)
//    cell.isFirstInSection = { ip in ip.item == 0 }
//    cell.isLastInSection = { [weak collectionView = self?.customView.collectionView] ip in
//      guard let collectionView = collectionView else { return false }
//      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
//    }
//  }
//  private lazy var finishSetupSectionHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListTitleView>>(
//    elementKind: .finishSetupSectionHeaderElementKind) { [weak viewModel] supplementaryView, elementKind, indexPath in
//      guard let viewModel else { return }
//      supplementaryView.configure(model: viewModel.finishSetupSectionHeaderModel)
//      supplementaryView.contentView.didTapButton = {
//        viewModel.didTapFinishSetupButton()
//      }
//  }

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
  }
  
  func setupBindings() {
    viewModel.didChangeWallet = { [weak self] in
      self?.scrollToTop(animated: false)
    }
    
    viewModel.didUpdateHeader = { [weak customView] model in
      customView?.headerView.configure(model: model)
    }
    
    viewModel.didUpdateSnapshot = { [weak self] snapshot, isAnimated in
      self?.dataSource.apply(snapshot, animatingDifferences: isAnimated)
    }

    viewModel.didCopy = { configuration in
      ToastPresenter.showToast(configuration: configuration)
    }
  }
  
  func createDataSource() -> DataSource {
    let itemCellConfiguration = BalanceItemCellConfiguration
    { [weak viewModel, weak collectionView = self.customView.collectionView] cell, indexPath, identifier in
      cell.isFirstInSection = { ip in ip.item == 0 }
      cell.isLastInSection = { ip in
        guard let collectionView = collectionView else { return false }
        return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
      }
      guard let model = viewModel?.getBalanceItemCellModel(item: identifier) else { return }
      cell.configure(configuration: model)
    }
    
    let dataSource = DataSource(
      collectionView: customView.collectionView) { [itemCellConfiguration] collectionView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let balanceItem as WalletBalanceItem:
          return collectionView.dequeueConfiguredReusableCell(
            using: itemCellConfiguration,
            for: indexPath,
            item: balanceItem
          )
        default:
          return nil
        }
      }
    
    let setupSectionHeaderRegistration = createSetupSectionHeaderRegistration()
    dataSource.supplementaryViewProvider = { [weak headerView = customView.headerView] collectionView, kind, indexPath -> UICollectionReusableView? in
      switch kind {
      case String.balanceHeaderElementKind:
        let view = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind, 
          withReuseIdentifier: TKReusableContainerView.reuseIdentifier,
          for: indexPath
        ) as? TKReusableContainerView
        view?.setContentView(headerView)
        return view
      case .setupSectionHeaderElementKind:
        return collectionView.dequeueConfiguredReusableSupplementary(using: setupSectionHeaderRegistration, for: indexPath)
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
  
  func createSetupSectionHeaderRegistration() -> SetupSectionHeaderRegistration {
    SetupSectionHeaderRegistration(elementKind: .setupSectionHeaderElementKind) { [weak self] supplementaryView, elementKind, indexPath in
      guard let self else { return }
      let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
      switch section {
      case .balance:
        return
      case .setup(let model):
        supplementaryView.configure(model: model)
        supplementaryView.contentView.didTapButton = { [weak self] in
          self?.viewModel.didTapFinishSetupButton()
        }
      }
    }
  }
  
  static func createLayoutSection(section: WalletBalanceSection) -> NSCollectionLayoutSection {
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
    
    let layoutSection = NSCollectionLayoutSection(group: group)
    layoutSection.contentInsets = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    
    switch section {
    case .balance:
      break
    case .setup:
      let headerSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .absolute(48)
      )
      let header = NSCollectionLayoutBoundarySupplementaryItem(
        layoutSize: headerSize,
        elementKind: .setupSectionHeaderElementKind,
        alignment: .top
      )
      layoutSection.boundarySupplementaryItems = [header]
    }
    return layoutSection
  }
}

extension WalletBalanceViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let section = snapshot.sectionIdentifiers[indexPath.section]
    let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
    switch item {
    case let item as WalletBalanceItem:
      viewModel.didSelectItem(item)
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
  static let setupSectionHeaderElementKind = "SetupSectionHeaderElementKind"
}
