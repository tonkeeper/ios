//
//  CollectibleDetailsCollectibleDetailsPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 21/08/2023.
//

import Foundation
import WalletCore

final class CollectibleDetailsPresenter {
  
  // MARK: - Module
  
  weak var viewInput: CollectibleDetailsViewInput?
  weak var output: CollectibleDetailsModuleOutput?
  
  // MARK: - Dependencies
  
  private let collectibleDetailsController: CollectibleDetailsController
  private let urlOpener: URLOpener
  
  // MARK: - Open URL
  
  private var openDetailsURL: (() -> Void)?
  
  // MARK: - Init
  
  init(collectibleDetailsController: CollectibleDetailsController,
       urlOpener: URLOpener) {
    self.collectibleDetailsController = collectibleDetailsController
    self.urlOpener = urlOpener
  }
}

// MARK: - CollectibleDetailsPresenterIntput

extension CollectibleDetailsPresenter: CollectibleDetailsPresenterInput {
  func viewDidLoad() {
    updateView()
  }
  
  func didTapSwipeButton() {
    output?.collectibleDetailsDidFinish(self)
  }
  
  func didTapOpenInExplorerButton() {
    openDetailsURL?()
  }
}

// MARK: - CollectibleDetailsModuleInput

extension CollectibleDetailsPresenter: CollectibleDetailsModuleInput {}

// MARK: - Private

private extension CollectibleDetailsPresenter {
  func updateView() {
    Task {
      let model = try collectibleDetailsController.getCollectibleModel()
      
      let collectibleModel = CollectibleDetailsCollectibleView.Model(
        title: model.collectibleDetails.title,
        subtitle: model.collectibleDetails.subtitle,
        description: model.collectibleDetails.description,
        imageURL: model.collectibleDetails.imageURL
      )
      
      let collectionModel = CollectibleDetailsCollectionDescriptionView.Model(
        title: model.collectionDetails.title,
        description: model.collectionDetails.description
      )
      
      
      let buttonsModel = CollectibleDetailsButtonsView.Model(buttonsModels:
        buttonsModels(model: model)
      )
      
      let propertiesModel = CollectibleDetailsPropertiesСarouselView.Model(
        titleModel: .init(title: "Properties"),
        propertiesModels: model.properties.map { .init(title: $0.title, value: $0.value) }
      )
      
      let listViewModel = model.details.items.map {
        ModalContentViewController.Configuration.ListItem(left: $0.title, rightTop: .value($0.value), rightBottom: .value(nil))
      }
      
      let detailsModel = CollectibleDetailsDetailsView.Model(
        titleViewModel: .init(title: "Details"),
        buttonTitle: "View in explorer",
        listViewModel: listViewModel
      )
      
      let viewModel = CollectibleDetailsView.Model(collectibleDescriptionModel: collectibleModel,
                                                   collectionDescriptionModel: collectionModel,
                                                   buttonsModel: buttonsModel,
                                                   propertiesModel: propertiesModel,
                                                   detailsModel: detailsModel)
      
      await MainActor.run {
        viewInput?.updateTitle(model.title)
        viewInput?.updateView(model: viewModel)
        
        openDetailsURL = { [weak self] in
          guard let url = model.details.url else { return }
          self?.urlOpener.open(url: url)
        }
      }
    }
  }
  
  func buttonsModels(model: CollectibleDetailsViewModel) -> [CollectibleDetailsButtonsView.Model.Button] {
    var transferButtonDescription: NSAttributedString?
    if model.isOnSale {
      transferButtonDescription = String.onSaleDescription.attributed(
        with: .body2,
        alignment: .center,
        lineBreakMode: .byWordWrapping,
        color: .Text.secondary)
    }
    
    let transferButtonModel = CollectibleDetailsButtonsView.Model.Button(
      title: "Transfer",
      configuration: .primaryLarge,
      isEnabled: model.isTransferEnable,
      tapAction: {
        print("Transfer!")
      },
      description: transferButtonDescription
    )
    return [transferButtonModel]
  }
}

private extension String {
  static let onSaleDescription = "Domain is on sale at the marketplace now. For transfer, you should remove it from sale first."
}
