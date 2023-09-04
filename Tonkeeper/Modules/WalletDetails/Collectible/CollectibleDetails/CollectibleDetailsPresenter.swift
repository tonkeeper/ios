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
    try? collectibleDetailsController.prepareCollectibleDetails()
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

extension CollectibleDetailsPresenter: CollectibleDetailsControllerDelegate {
  func collectibleDetailsController(_ collectibleDetailsController: CollectibleDetailsController,
                                    didUpdate model: CollectibleDetailsViewModel) {
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
    
    var propertiesModel: CollectibleDetailsPropertiesСarouselView.Model?
    if !model.properties.isEmpty {
      propertiesModel = CollectibleDetailsPropertiesСarouselView.Model(
        titleModel: .init(title: "Properties"),
        propertiesModels: model.properties.map { .init(title: $0.title, value: $0.value) }
      )
    }
    
    var listViewModel = model.details.items.map {
      ModalContentViewController.Configuration.ListItem(left: $0.title, rightTop: .value($0.value), rightBottom: .value(nil))
    }
    
    if let expirationDateItem = model.expirationDateItem, case let .value(value) = expirationDateItem {
      let listItem = ModalContentViewController.Configuration.ListItem(
        left: .expirationDateTitle,
        rightTop: .value(value),
        rightBottom: .value(nil))
      listViewModel.insert(listItem, at: 1)
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
    
    viewInput?.updateTitle(model.title)
    viewInput?.updateView(model: viewModel)
    
    openDetailsURL = { [weak self] in
      guard let url = model.details.url else { return }
      self?.urlOpener.open(url: url)
    }
  }
}

// MARK: - Private

private extension CollectibleDetailsPresenter {
  func buttonsModels(model: CollectibleDetailsViewModel) -> [CollectibleDetailsButtonsView.Model.Button] {
    let transferButtonModel = createTransferButtonModel(model: model)
    let linkButtonModel = createLinkButtonModel(model: model)
    var models = [transferButtonModel, linkButtonModel]
    if let expirationDateButtonModel = createExpirationDateButtonModel(model: model) {
      models.append(expirationDateButtonModel)
    }
    return models
  }
  
  func createLinkButtonModel(model: CollectibleDetailsViewModel) -> CollectibleDetailsButtonsView.Model.Button {
    let title: String
    let isLoading: Bool
    switch model.linkedAddress {
    case .value(let value):
      if let value = value {
        title = "Linked with \(value)"
      } else {
        title = "Link domain"
      }
      isLoading = false
    case .loading:
      title = ""
      isLoading = true
    }
    
    let buttonModel = CollectibleDetailsButtonsView.Model.Button(
      title: title,
      configuration: .secondaryLarge,
      isEnabled: false,
      isLoading: isLoading, tapAction: {}, description: nil)
    
    return buttonModel
  }
  
  func createExpirationDateButtonModel(model: CollectibleDetailsViewModel) -> CollectibleDetailsButtonsView.Model.Button? {
    guard let expirationDateItem = model.expirationDateItem else { return nil }

    var daysExpirationDescription: NSAttributedString?
    if let daysExpiration = model.daysExpiration {
      let string = "Expires in \(daysExpiration) days"
      daysExpirationDescription = string.attributed(
        with: .body2,
        alignment: .center,
        lineBreakMode: .byWordWrapping,
        color: .Text.secondary)
    }
  
    let title: String
    let isLoading: Bool
    switch expirationDateItem {
    case .value(let value):
      title = "Renew until \(value)"
      isLoading = false
    case .loading:
      title = ""
      isLoading = true
    }

    let buttonModel = CollectibleDetailsButtonsView.Model.Button(
      title: title,
      configuration: .secondaryLarge,
      isEnabled: false,
      isLoading: isLoading,
      tapAction: {},
      description: daysExpirationDescription)

    return buttonModel
  }
  
  func createTransferButtonModel(model: CollectibleDetailsViewModel) -> CollectibleDetailsButtonsView.Model.Button {
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
      isLoading: false,
      tapAction: { [weak self] in
        guard let self = self else { return }
        self.output?.collectibleDetails(
          self,
          transferNFT: self.collectibleDetailsController.collectibleAddress)
      },
      description: transferButtonDescription
    )
    
    return transferButtonModel
  }
}

private extension String {
  static let onSaleDescription = "Domain is on sale at the marketplace now. For transfer, you should remove it from sale first."
  static let expirationDateTitle = "Expiration date"
}
