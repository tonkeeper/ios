//
//  SendConfirmationModalConfigurationBuilder.swift
//  Tonkeeper
//
//  Created by Grigory on 5.6.23..
//

import Foundation

struct SendConfirmationModalConfigurationBuilder {
  
  static func configuration(title: String,
                            image: Image,
                            recipientName: String? = nil,
                            recipientAddress: String? = nil,
                            amount: String? = nil,
                            fiatAmount: ModalContentViewController.Configuration.ListItem.RightItem<String?>,
                            fee: ModalContentViewController.Configuration.ListItem.RightItem<String?>,
                            fiatFee: ModalContentViewController.Configuration.ListItem.RightItem<String?>,
                            comment: String? = nil,
                            isButtonEnabled: Bool = true,
                            showActivity: Bool = true,
                            showActivityOnTap: Bool = true,
                            tapAction: (( @escaping (Bool) -> Void ) -> Void)? = nil,
                            completion: ((Bool) -> Void)? = nil
  ) -> ModalContentViewController.Configuration {
    let header = ModalContentViewController.Configuration.Header(
      image: image,
      imageShape: .circle,
      title: title,
      topDescription: .description
    )
    
    var listItems = [ModalContentViewController.Configuration.ListItem]()
    if let recipientName = recipientName {
      listItems.append(.init(left: .recipientTitle, rightTop: .value(recipientName), rightBottom: .value(nil)))
    }
    if let recipientAddress = recipientAddress {
      listItems.append(.init(left: .recipientAddressTitle, rightTop: .value(recipientAddress), rightBottom: .value(nil)))
    }
    
    if let amount = amount {
      listItems.append(.init(left: .amountTitle, rightTop: .value(amount), rightBottom: fiatAmount))
    }
    
    switch fee {
    case .loading:
      listItems.append(.init(left: .feeTitle, rightTop: .loading, rightBottom: fiatFee))
    case .value(let value):
      if let value = value {
        listItems.append(.init(left: .feeTitle, rightTop: .value(value), rightBottom: fiatFee))
      }
    }
    
    if let comment = comment, !comment.isEmpty {
      listItems.append(.init(left: .commentTitle, rightTop: .value(comment), rightBottom: .value(nil)))
    }
    
    let buttons = ModalContentViewController.Configuration.ActionBar.Button(
      title: .buttonTitle,
      configuration: .primaryLarge,
      isEnabled: isButtonEnabled,
      tapAction: tapAction,
      showActivity: { showActivity },
      showActivityOnTap: { showActivityOnTap },
      completion: completion
    )
    
    let actionBarItems: [ModalContentViewController.Configuration.ActionBar.Item] = [
      .buttons([buttons])
    ]
    
    let actionBar = ModalContentViewController.Configuration.ActionBar(items: actionBarItems)
    
    let configuration = ModalContentViewController.Configuration(
      header: header,
      listItems: listItems,
      actionBar: actionBar)
    
    return configuration
  }
  
  static func nftSendConfiguration(title: String,
                                   description: String,
                                   image: Image,
                                   recipientName: String? = nil,
                                   recipientAddress: String? = nil,
                                   fee: ModalContentViewController.Configuration.ListItem.RightItem<String?>,
                                   fiatFee: ModalContentViewController.Configuration.ListItem.RightItem<String?>,
                                   comment: String? = nil,
                                   nftId: String? = nil,
                                   nftCollectionId: String? = nil,
                                   isButtonEnabled: Bool = true,
                                   showActivity: Bool = true,
                                   showActivityOnTap: Bool = true,
                                   tapAction: (( @escaping (Bool) -> Void ) -> Void)? = nil,
                                   completion: ((Bool) -> Void)? = nil
  ) -> ModalContentViewController.Configuration {
    let header = ModalContentViewController.Configuration.Header(
      image: image,
      imageShape: .roundedRect(cornerRadius: 20),
      title: title,
      topDescription: description
    )
    
    var listItems = [ModalContentViewController.Configuration.ListItem]()
    if let recipientName = recipientName {
      listItems.append(.init(left: .recipientTitle, rightTop: .value(recipientName), rightBottom: .value(nil)))
    }
    if let recipientAddress = recipientAddress {
      listItems.append(.init(left: .recipientAddressTitle, rightTop: .value(recipientAddress), rightBottom: .value(nil)))
    }
    
    switch fee {
    case .loading:
      listItems.append(.init(left: .feeTitle, rightTop: .loading, rightBottom: fiatFee))
    case .value(let value):
      if let value = value {
        listItems.append(.init(left: .feeTitle, rightTop: .value(value), rightBottom: fiatFee))
      }
    }
    
    if let comment = comment, !comment.isEmpty {
      listItems.append(.init(left: .commentTitle, rightTop: .value(comment), rightBottom: .value(nil)))
    }
    
    if let nftCollectionId = nftCollectionId {
      listItems.append(.init(left: .nftCollectionID, rightTop: .value(nftCollectionId), rightBottom: .value(nil)))
    }
    
    if let nftId = nftId {
      listItems.append(.init(left: .nftItemID, rightTop: .value(nftId), rightBottom: .value(nil)))
    }
    
    let buttons = ModalContentViewController.Configuration.ActionBar.Button(
      title: .buttonTitle,
      configuration: .primaryLarge,
      isEnabled: isButtonEnabled,
      tapAction: tapAction,
      showActivity: { showActivity },
      showActivityOnTap: { showActivityOnTap },
      completion: completion
    )
    
    let actionBarItems: [ModalContentViewController.Configuration.ActionBar.Item] = [
      .buttons([buttons])
    ]
    
    let actionBar = ModalContentViewController.Configuration.ActionBar(items: actionBarItems)
    
    let configuration = ModalContentViewController.Configuration(
      header: header,
      listItems: listItems,
      actionBar: actionBar)
    
    return configuration
  }
  
  static func actionBarConfiguration(showActivity: Bool = true,
                                     showActivityOnTap: Bool = true,
                                     tapAction: (( @escaping (Bool) -> Void ) -> Void)? = nil,
                                     completion: ((Bool) -> Void)? = nil) -> ModalContentViewController.Configuration.ActionBar {
    let buttons = ModalContentViewController.Configuration.ActionBar.Button(
      title: .buttonTitle,
      configuration: .primaryLarge,
      tapAction: tapAction,
      showActivity: {
        showActivity
        
      },
      showActivityOnTap: {
        showActivityOnTap
        
      },
      completion: completion
    )
    
    let actionBarItems: [ModalContentViewController.Configuration.ActionBar.Item] = [
      .buttons([buttons])
    ]
    
    let actionBar = ModalContentViewController.Configuration.ActionBar(items: actionBarItems)
    return actionBar
  }
}

private extension String {
  static let description = "Confirm action"
  static let recipientTitle = "Recipient"
  static let recipientAddressTitle = "Recipient address"
  static let amountTitle = "Amount"
  static let feeTitle = "Fee"
  static let commentTitle = "Comment"
  static let nftItemID = "NFT item ID"
  static let nftCollectionID = "NFT collection ID"
  static let buttonTitle = "Confirm and send"
}
