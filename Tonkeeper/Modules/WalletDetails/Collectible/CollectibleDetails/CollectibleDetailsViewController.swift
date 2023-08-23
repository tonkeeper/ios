//
//  CollectibleDetailsCollectibleDetailsViewController.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 21/08/2023.
//

import UIKit

class CollectibleDetailsViewController: GenericViewController<CollectibleDetailsView> {

  // MARK: - Module

  private let presenter: CollectibleDetailsPresenterInput

  // MARK: - Init

  init(presenter: CollectibleDetailsPresenterInput) {
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

// MARK: - CollectibleDetailsViewInput

extension CollectibleDetailsViewController: CollectibleDetailsViewInput {
  func updateDetailsSection(model: CollectibleDetailsDetailsView.Model) {
    customView.detailsView.configure(model: model)
  }
  
  func updateContentSection(model: CollectibleDetailsCollectionDescriptionView.Model) {
    customView.collectionDescriptionView.configure(model: model)
  }
}

// MARK: - Private

private extension CollectibleDetailsViewController {
  func setup() {
    setupSwipeButton { [weak self] in
      self?.presenter.didTapSwipeButton()
    }
  }
}
