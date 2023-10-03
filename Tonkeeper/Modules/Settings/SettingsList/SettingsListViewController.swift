//
//  SettingsListSettingsListViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 25/09/2023.
//

import UIKit

class SettingsListViewController: GenericViewController<SettingsListView> {

  // MARK: - Module

  private let presenter: SettingsListPresenterInput
  
  // MARK: - Collection
  
  private lazy var collectionController: SettingsListCollectionController = {
    let controller = SettingsListCollectionController(collectionView: customView.collectionView)
    return controller
  }()

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
}

// MARK: - SettingsListViewInput

extension SettingsListViewController: SettingsListViewInput {
  func didUpdateSettings(_ sections: [[SettingsListCellContentView.Model]]) {
    collectionController.sections = sections
  }
}

// MARK: - Private

private extension SettingsListViewController {
  func setup() {
    title = presenter.title
    navigationItem.largeTitleDisplayMode = presenter.isTitleLarge ? .always : .never
  }
}
