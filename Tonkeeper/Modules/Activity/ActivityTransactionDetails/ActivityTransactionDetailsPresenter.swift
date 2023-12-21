//
//  ActivityTransactionDetailsActivityTransactionDetailsPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import Foundation
import WalletCoreKeeper
import TKUIKit
import TKCore

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
    configureOpenTransactionButton()
    configureDetails()
  }
}

// MARK: - ActivityTransactionDetailsModuleInput

extension ActivityTransactionDetailsPresenter: ActivityTransactionDetailsModuleInput {}

// MARK: - Private

private extension ActivityTransactionDetailsPresenter {
  func configureOpenTransactionButton() {
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
    viewInput?.updateOpenTransactionButton(with: model)
  }
  
  func configureDetails() {
    let model = activityEventDetailsController.model
    
    var headerItems = [ModalCardViewController.Configuration.Item]()
    
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
        rightTop: .value($0.topValue),
        rightBottom: .value($0.bottomValue))
    }
    let list = ModalCardViewController.Configuration.ContentItem.list(listItems)

    let configuration = ModalCardViewController.Configuration(
      header: ModalCardViewController.Configuration.Header(items: headerItems),
      content: ModalCardViewController.Configuration.Content(items: [list]),
      actionBar: nil
    )
    viewInput?.update(with: configuration)
  }
}
