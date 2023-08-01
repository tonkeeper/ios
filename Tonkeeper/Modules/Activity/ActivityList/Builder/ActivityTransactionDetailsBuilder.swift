//
//  ActivityTransactionDetailsBuilder.swift
//  Tonkeeper
//
//  Created by Grigory on 9.6.23..
//

import Foundation

struct ActivityTransactionDetailsBuilder {
  static func configuration(title: String,
                            description: String,
                            fixDescription: String?,
                            recipientAddress: String,
                            transaction: String,
                            fee: String,
                            feeFiat: String,
                            message: String? = nil,
                            tapAction: (( @escaping (Bool) -> Void ) -> Void)? = nil
  ) -> ModalContentViewController.Configuration {
    let header = ModalContentViewController.Configuration.Header(
      image: nil,
      title: title,
      bottomDescription: description,
      fixBottomDescription: fixDescription
    )
    
    var listItems: [ModalContentViewController.Configuration.ListItem] = [
      .init(left: .recipientAddressTitle, rightTop: .value(recipientAddress), rightBottom: .value(nil)),
      .init(left: .transactionTitle, rightTop: .value(transaction), rightBottom: .value(nil)),
      .init(left: .feeTitle, rightTop: .value(fee), rightBottom: .value(feeFiat)),
    ]
    
    if let message = message {
      listItems.append(.init(left: .messageTitle, rightTop: .value(message), rightBottom: .value(nil)))
    }
    
    let buttons = ModalContentViewController.Configuration.ActionBar.Button(
      title: .viewDetailsButtonTitle,
      configuration: .secondaryLarge,
      tapAction: tapAction
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
}

private extension String {
  static let recipientAddressTitle = "Recipient address"
  static let transactionTitle = "Transaction"
  static let feeTitle = "Fee"
  static let messageTitle = "Message"
  static let viewDetailsButtonTitle = "View in explorer"
}

