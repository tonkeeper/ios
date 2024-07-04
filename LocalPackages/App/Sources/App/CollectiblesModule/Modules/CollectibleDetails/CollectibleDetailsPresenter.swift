import Foundation
import UIKit
import TKUIKit
import TKCore
import KeeperCore

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
    setup()
  }
}

private extension CollectibleDetailsPresenter {
  func setup() {
    collectibleDetailsController.didUpdateModel = { [weak self] model in
      self?.setupWithModel(model: model)
    }
  }
  
  func setupWithModel(model: CollectibleDetailsModel) {
    let collectibleModel = CollectibleDetailsCollectibleView.Model(
      title: model.collectibleDetails.title,
      subtitle: model.collectibleDetails.subtitle,
      description: model.collectibleDetails.description,
      imageURL: model.collectibleDetails.imageURL
    )
    
    var collectionModel: CollectibleDetailsCollectionDescriptionView.Model?
    if let collectionDetails = model.collectionDetails {
      collectionModel = .init(
        title: collectionDetails.title,
        description: collectionDetails.description
      )
    }
    
    let buttonsModel = CollectibleDetailsButtonsView.Model(buttonsModels:
      buttonsModels(model: model)
    )
    
    var propertiesModel: CollectibleDetailsPropertiesСarouselView.Model?
    if !model.properties.isEmpty {
      propertiesModel = CollectibleDetailsPropertiesСarouselView.Model(
        titleModel: .init(title: "Properties", textStyle: .h3),
        propertiesModels: model.properties.map { .init(title: $0.title, value: $0.value) }
      )
    }
    
    var listViewModel = model.details.items.map {
      TKModalCardViewController.Configuration.ListItem.defaultItem(
        left: $0.title,
        rightTop: .value($0.value.short, numberOfLines: 1, isFullString: false),
        rightBottom: .value(nil, numberOfLines: 1, isFullString: false),
        modelValue: $0.value.full
      )
    }
    
    if let expirationDateItem = model.expirationDateItem, case let .value(value) = expirationDateItem {
      let listItem = TKModalCardViewController.Configuration.ListItem.defaultItem(
        left: .expirationDateTitle,
        rightTop: .value(value, numberOfLines: 1, isFullString: false),
        rightBottom: .value(nil, numberOfLines: 1, isFullString: false)
      )
      listViewModel.insert(listItem, at: 1)
    }
    
    let detailsModel = CollectibleDetailsDetailsView.Model(
      titleViewModel: TKListTitleView.Model(title: "Details", textStyle: .h3),
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

// MARK: - Private

private extension CollectibleDetailsPresenter {
  func buttonsModels(model: CollectibleDetailsModel) -> [CollectibleDetailsButtonsView.Model.Button] {
    var models = [createTransferButtonModel(model: model)]
    if let linkButton = createLinkButtonModel(model: model) {
      models.append(linkButton)
    }
    if let expirationDateButtonModel = createExpirationDateButtonModel(model: model) {
      models.append(expirationDateButtonModel)
    }
    return models
  }
  
  func createLinkButtonModel(model: CollectibleDetailsModel) -> CollectibleDetailsButtonsView.Model.Button? {
    guard let linkedAddress = model.linkedAddress else { return nil }
    let title: String
    let isLoading: Bool
    let isLinked: Bool?
    switch linkedAddress {
    case .value(let value):
      if let value = value {
        title = "Linked with \(value)"
        isLinked = true
      } else {
        title = "Link domain"
        isLinked = false
      }
      isLoading = false
    case .loading:
      title = ""
      isLoading = true
      isLinked = nil
    }

    let buttonModel = CollectibleDetailsButtonsView.Model.Button(
      title: title,
      category: .secondary,
      size: .large,
      isEnabled: true,
      isLoading: isLoading, tapAction: { [weak self] in
        guard let isLinked else { return }
        self?.handleLinkButton(isLinked: isLinked)
      }, description: nil
    )
    
    return buttonModel
  }
  
  func createExpirationDateButtonModel(model: CollectibleDetailsModel) -> CollectibleDetailsButtonsView.Model.Button? {
    guard let expirationDateItem = model.expirationDateItem else { return nil }

    var daysExpirationDescription: NSAttributedString?
    if let daysExpiration = model.daysExpiration {
      let string = "Expires in \(daysExpiration) days"
      daysExpirationDescription = string.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    }
  
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    switch expirationDateItem {
    case .value:
      title = "Renew until \(model.renewButtonDateItem ?? "")"
      isLoading = false
      isEnabled = true
    case .loading:
      title = ""
      isLoading = true
      isEnabled = false
    }
    
    let buttonModel = CollectibleDetailsButtonsView.Model.Button(
      title: title,
      category: .secondary,
      size: .large,
      isEnabled: isEnabled,
      isLoading: isLoading,
      tapAction: { [weak self] in
        guard let self = self else { return }
        self.output?.collectibleDetailsRenewDomain(self, nft: self.collectibleDetailsController.nft)
      },
      description: daysExpirationDescription
    )

    return buttonModel
  }
  
  func createTransferButtonModel(model: CollectibleDetailsModel) -> CollectibleDetailsButtonsView.Model.Button {
    var transferButtonDescription: NSAttributedString?
    if model.isOnSale {
      let description: String = model.isDns ? .domainOnSaleDescription : .nftOnSaleDescription
      transferButtonDescription = description.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    }
    
    let buttonModel = CollectibleDetailsButtonsView.Model.Button(
      title: "Transfer",
      category: .primary,
      size: .large,
      isEnabled: model.isTransferEnable,
      isLoading: false, tapAction: { [weak self] in
        guard let self = self else { return }
        self.output?.collectibleDetails(
          self,
          transferNFT: self.collectibleDetailsController.nft)
      }, 
      description: transferButtonDescription
    )
    return buttonModel
  }
  
  func handleLinkButton(isLinked: Bool) {
    isLinked ? unlinkDomain() : linkDomain()
  }
  
  func linkDomain() {
    output?.collectibleDetailsLinkDomain(self, nft: collectibleDetailsController.nft)
  }
  
  func unlinkDomain() {
    output?.collectibleDetailsUnlinkDomain(self, nft: collectibleDetailsController.nft)
  }
}

private extension String {
  static let domainOnSaleDescription = "Domain is on sale at the marketplace now. For transfer, you should remove it from sale first."
  static let nftOnSaleDescription = "NFT is on sale at the marketplace now. For transfer, you should remove it from sale first."
  static let expirationDateTitle = "Expiration date"
}
