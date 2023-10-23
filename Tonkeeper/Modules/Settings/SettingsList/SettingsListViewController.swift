//
//  SettingsListSettingsListViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import UIKit

class SettingsListViewController: GenericViewController<SettingsListView>, ScrollViewController {

  // MARK: - Module

  private let presenter: SettingsListPresenterInput
  
  // MARK: - Collection
  
  private var biggestTopSafeAreaInset: CGFloat = 0
  private lazy var collectionController: SettingsListCollectionController = {
    let controller = SettingsListCollectionController(collectionView: customView.collectionView)
    return controller
  }()
  
  // MARK: - Footer
  
  private let footerView = SettingsListFooterView()

  // MARK: - Init

  init(presenter: SettingsListPresenterInput) {
    self.presenter = presenter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    presenter.viewDidLoad()
  }
  
  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    self.biggestTopSafeAreaInset = max(view.safeAreaInsets.top, biggestTopSafeAreaInset)
  }
  
  // MARK: - ScrollViewController
  
  func scrollToTop() {
    customView.collectionView.setContentOffset(
      CGPoint(x: 0,
              y: -biggestTopSafeAreaInset),
      animated: true
    )
  }
}

// MARK: - SettingsListViewInput

extension SettingsListViewController: SettingsListViewInput {
  func didUpdateSettings(_ sections: [[SettingsListCellContentView.Model]]) {
    collectionController.sections = sections
  }
  
  func updateFooter(_ footerModel: SettingsListFooterView.Model) {
    footerView.configure(model: footerModel)
  }
  
  func openKeychainRestore() {
    let vc = WalletRestoreViewController()
    present(vc, animated: true)
  }
  
  func showAlert(title: String, description: String?, actions: [UIAlertAction]) {
    let alertController = UIAlertController(
      title: title,
      message: description,
      preferredStyle: .alert
    )
    alertController.overrideUserInterfaceStyle = .dark
    actions.forEach { alertController.addAction($0) }
    present(alertController, animated: true)
  }
}

// MARK: - Private

private extension SettingsListViewController {
  func setup() {
    title = presenter.title
    navigationItem.largeTitleDisplayMode = presenter.isTitleLarge ? .always : .never
    
    collectionController.footerView = footerView
    customView.collectionView.contentInset.bottom = ContentInsets.bottomSpace
  }
}
