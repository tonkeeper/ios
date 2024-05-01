import UIKit
import TKUIKit

final class KeyDetailsViewController: GenericViewViewController<KeyDetailsView> {
  private let viewModel: KeyDetailsViewModel

  private lazy var collectionController = KeyDetailsCollectionController(
    collectionView: customView.collectionView
  )
  
  init(viewModel: KeyDetailsViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension KeyDetailsViewController {
  func setupBindings() {
    viewModel.titleUpdate = { [weak self] title in
      self?.title = title
    }
    
    viewModel.itemsListUpdate = { [weak self] items in
      self?.collectionController.setItems(items)
    }
    
    viewModel.didSelectDelete = { [weak self] in
      self?.showDeleteAlert()
    }
    
    viewModel.didOpenUrl = { [weak self] url in
      self?.openUrl(url: url)
    }
    
    viewModel.didCopied = {
      ToastPresenter.showToast(configuration: .copied)
    }
  }
  
  func showDeleteAlert() {
    let alertController = UIAlertController(
      title: "Delete Key?",
      message: "This will erase keys to the wallet. Make sure you have backed up your secret recovery phrase.",
      preferredStyle: .alert
    )
    alertController.addAction(
      UIAlertAction(
        title: "Cancel",
        style: .cancel
      )
    )
    alertController.addAction(
      UIAlertAction(
        title: "Delete Key",
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
}
