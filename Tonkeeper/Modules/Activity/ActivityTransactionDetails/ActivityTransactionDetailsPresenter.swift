import Foundation
import WalletCoreKeeper
import TKUIKit
import TKCore
import UIKit

final class ActivityTransactionDetailsPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ActivityTransactionDetailsViewInput?
  weak var output: ActivityTransactionDetailsModuleOutput?
  
  private let activityEventDetailsController: ActivityEventDetailsController
  private let urlOpener: URLOpener
  
  init(activityEventDetailsController: ActivityEventDetailsController,
       urlOpener: URLOpener) {
    self.activityEventDetailsController = activityEventDetailsController
    self.urlOpener = urlOpener
  }
}

// MARK: - ActivityTransactionDetailsPresenterIntput

extension ActivityTransactionDetailsPresenter: ActivityTransactionDetailsPresenterInput {
  func viewDidLoad() {
    configureDetails()
  }
}

// MARK: - ActivityTransactionDetailsModuleInput

extension ActivityTransactionDetailsPresenter: ActivityTransactionDetailsModuleInput {}

// MARK: - Private

private extension ActivityTransactionDetailsPresenter {
  func configureDetails() {
    let model = activityEventDetailsController.model
    
    var headerItems = [ModalCardViewController.Configuration.Item]()
    
    if let headerImage = model.headerImage {
      switch headerImage {
      case .swap(let fromImage, let toImage):
        let view = SwapHeaderImageView()
        view.imageLoader = NukeImageLoader()
        view.configure(model: SwapHeaderImageView.Model(
          leftImage: .with(image: fromImage),
          rightImage: .with(image: toImage))
        )
        headerItems.append(ModalCardViewController.Configuration.Item.customView(view, bottomSpacing: 20))
      case .image(let image):
        let view = ActionDetailsTokenHeaderImageView()
        view.imageLoader = NukeImageLoader()
        view.configure(model: ActionDetailsTokenHeaderImageView.Model(
          image: .with(image: image)
        ))
        headerItems.append(ModalCardViewController.Configuration.Item.customView(view, bottomSpacing: 20))
      case .nft(let image):
        let view = ActionDetailsNFTHeaderImageView()
        view.imageLoader = NukeImageLoader()
        view.configure(model: ActionDetailsNFTHeaderImageView.Model(
          image: .with(image: .url(image))
        ))
        headerItems.append(ModalCardViewController.Configuration.Item.customView(view, bottomSpacing: 20))
      }
    }
    
    if let nftName = model.nftName {
      headerItems.append(.text(.init(text: nftName.attributed(with: .h2, alignment: .center, color: .Text.primary), numberOfLines: 1), bottomSpacing: 0))
      if let nftCollectionName = model.nftCollectionName {
        headerItems.append(.text(.init(text: nftCollectionName.attributed(with: .body1, alignment: .center, color: .Text.secondary), numberOfLines: 1), bottomSpacing: 0))
      }
      headerItems.append(.customView(SpacingView(verticalSpacing: .constant(16)), bottomSpacing: 0))
    }
    
    if let aboveTitle = model.aboveTitle {
      headerItems.append(.text(.init(text: aboveTitle.attributed(with: .h2, alignment: .center, color: .Text.tertiary), numberOfLines: 1), bottomSpacing: 4))
    }
    if let title = model.title {
      headerItems.append(.text(.init(text: title.attributed(with: .h2, alignment: .center, color: .Text.primary), numberOfLines: 1), bottomSpacing: 4))
    }
    if let fiatPrice = model.fiatPrice {
      headerItems.append(.text(.init(text: fiatPrice.attributed(with: .body1, alignment: .center, color: .Text.secondary), numberOfLines: 1), bottomSpacing: 4))
    }
    if let date = model.date {
      headerItems.append(.text(.init(text: date.attributed(with: .body1, alignment: .center, color: .Text.secondary), numberOfLines: 1), bottomSpacing: 0))
    }
    
    if let status = model.status {
      headerItems.append(.text(.init(text: status.attributed(with: .body1, alignment: .center, color: .Accent.orange), numberOfLines: 1), bottomSpacing: 0))
      headerItems.append(.customView(SpacingView(verticalSpacing: .constant(16)), bottomSpacing: 0))
    }
    
    let listItems = model.listItems.map {
      ModalCardViewController.Configuration.ListItem(
        left: $0.title,
        rightTop: .value($0.topValue, numberOfLines: $0.topNumberOfLines),
        rightBottom: .value($0.bottomValue, numberOfLines: 1))
    }
    let list = ModalCardViewController.Configuration.ContentItem.list(listItems)
    let buttonItem = ModalCardViewController.Configuration.ContentItem.item(.customView(createOpenTransactionButtonContainerView(), bottomSpacing: 32))

    let configuration = ModalCardViewController.Configuration(
      header: ModalCardViewController.Configuration.Header(items: headerItems),
      content: ModalCardViewController.Configuration.Content(items: [list, buttonItem]),
      actionBar: nil
    )
    viewInput?.update(with: configuration)
  }
}

private extension ActivityTransactionDetailsPresenter {
  func createOpenTransactionButtonContainerView() -> UIView {
    let buttonContainer = UIView()
    let button = TKButtonControl(buttonContent: OpenTransactionTKButtonContentView(),
                                 buttonCategory: .secondary,
                                 buttonSize: .small)
    buttonContainer.addSubview(button)
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
      button.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
      button.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor)
    ])
    
    let model = TKButtonControl<OpenTransactionTKButtonContentView>.Model(
      contentModel: OpenTransactionTKButtonContentView.Model(
        title: "Transaction ",
        transactionHash: activityEventDetailsController.transactionHash,
        image: .Icons.Size16.globe16
      ),
      action: { [urlOpener, activityEventDetailsController] in
        urlOpener.open(url: activityEventDetailsController.transactionURL)
      }
    )
    button.configure(model: model)
    return buttonContainer
  }
}
