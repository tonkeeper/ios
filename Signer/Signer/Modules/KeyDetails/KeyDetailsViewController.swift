import UIKit
import TKUIKit
import SignerLocalize

final class KeyDetailsViewController: GenericViewViewController<KeyDetailsView> {
  private let viewModel: KeyDetailsViewModel
  
  private lazy var dataSource = createDataSource()
  
  private lazy var listItemCellRegistration = UICollectionView.CellRegistration<TKUIListItemCell, TKUIListItemCell.Configuration>(handler: { 
    [weak self] cell,
    indexPath,
    itemIdentifier in
    cell.configure(configuration: itemIdentifier)
    cell.isFirstInSection = { ip in ip.item == 0 }
    cell.isLastInSection = { ip in
      guard let collectionView = self?.customView.collectionView else { return false }
      return ip.item == (collectionView.numberOfItems(inSection: ip.section) - 1)
    }
  })
  
  private lazy var qrCodeCellRegistration = UICollectionView.CellRegistration<KeyDetailsQRCodeCell, KeyDetailsQRCodeCell.Model> { cell, indexPath, itemIdentifier in
    cell.configure(model: itemIdentifier)
  }

  private lazy var layout: UICollectionViewCompositionalLayout = {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(
      sectionProvider: { [weak dataSource, weak self] sectionIndex, _ -> NSCollectionLayoutSection? in
        guard let dataSource, let self else { return nil }
        let snapshot = dataSource.snapshot()
        let insets: NSDirectionalEdgeInsets
        switch snapshot.sectionIdentifiers[sectionIndex].type {
        case .actions: 
          insets = NSDirectionalEdgeInsets(top: 48, leading: 16, bottom: 16, trailing: 16)
        case .delete:
          insets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        case .deviceLink:
          insets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        case .webLink:
          insets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        case .qrCode:
          insets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        }
        return self.layoutSection(insets: insets)
      },
      configuration: configuration
    )
    
    return layout
  }()
  
  private var cachedWidth: CGFloat?
  
  init(viewModel: KeyDetailsViewModel) {
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
    if view.bounds.width != cachedWidth {
      cachedWidth = view.bounds.width
      viewModel.generateQRCode(width: view.bounds.width)
    }
  }
}

private extension KeyDetailsViewController {
  func setup() {
    customView.collectionView.contentInset.top = 16
    customView.collectionView.delegate = self
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
  }
  
  func setupBindings() {
    viewModel.titleUpdate = { [weak self] title in
      self?.title = title
    }
    
    viewModel.itemsListUpdate = { [weak self] items in
      self?.dataSource.apply(items, animatingDifferences: false)
    }
    
    viewModel.didSelectDelete = { [weak self] in
      self?.showDeleteAlert()
    }
    
    viewModel.didOpenUrl = { [weak self] url in
      self?.openUrl(url: url)
    }
    
    viewModel.didCopied = {
      ToastPresenter.showToast(configuration: .Signer.copied)
    }
  }
  
  func showDeleteAlert() {
    let alertController = UIAlertController(
      title: SignerLocalize.KeyDetails.DeleteAlert.title,
      message: SignerLocalize.KeyDetails.DeleteAlert.description,
      preferredStyle: .alert
    )
    alertController.addAction(
      UIAlertAction(
        title: SignerLocalize.Actions.cancel,
        style: .cancel
      )
    )
    alertController.addAction(
      UIAlertAction(
        title: SignerLocalize.KeyDetails.DeleteAlert.Buttons.delete_key,
        style: .destructive,
        handler: { [weak self] _ in
          self?.viewModel.didConfirmDelete()
        }
      )
    )
    present(alertController, animated: true)
  }
  
  func openUrl(url: URL) {
    UIApplication.shared.open(url)
  }
  
  func createDataSource() -> UICollectionViewDiffableDataSource<KeyDetailsSection, AnyHashable> {
    let dataSource = UICollectionViewDiffableDataSource<KeyDetailsSection, AnyHashable>(
      collectionView: customView.collectionView) { [listItemCellRegistration, qrCodeCellRegistration]
        collectionView,
        indexPath,
        itemIdentifier in
        switch itemIdentifier {
        case let listItemConfiguration as TKUIListItemCell.Configuration:
          return collectionView.dequeueConfiguredReusableCell(
            using: listItemCellRegistration,
            for: indexPath,
            item: listItemConfiguration
          )
        case let qrCodeCellModel as KeyDetailsQRCodeCell.Model:
          return collectionView.dequeueConfiguredReusableCell(
            using: qrCodeCellRegistration,
            for: indexPath,
            item: qrCodeCellModel
          )
        default:
          return nil
        }
      }
    return dataSource
  }
  
  func layoutSection(insets: NSDirectionalEdgeInsets) -> NSCollectionLayoutSection {
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
    section.contentInsets = insets
    return section
  }
}

extension KeyDetailsViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let snapshot = dataSource.snapshot()
    let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.item]
    switch item {
    case let listItem as TKUIListItemCell.Configuration:
      listItem.selectionClosure?()
    default: break
    }
  }
}
