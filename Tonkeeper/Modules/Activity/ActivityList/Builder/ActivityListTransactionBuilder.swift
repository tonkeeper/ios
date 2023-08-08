//
//  ActivityListTransactionBuilder.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import Foundation
import UIKit
import WalletCore

struct ActivityListTransactionBuilder {
  func buildTransactionModel(type: ActivityEventViewModel.ActionViewModel.ActionType,
                             subtitle: String?,
                             amount: String?,
                             time: String?,
                             status: String?,
                             comment: String? = nil) -> TransactionCellContentView.Model {
    
    let textContentModel = DefaultCellTextContentView.Model(
      leftTopTitle: type.title,
      leftTopRightTitle: nil,
      rightTopTitle: amount?.attributed(with: .label1, alignment: .left, color: type.amountColor),
      leftMiddleTitle: subtitle,
      leftMiddleRightTitle: nil,
      rightMiddleTitle: time,
      leftBottomTitle: nil,
      rightBottomTitle: nil
    )
    let contentModel = DefaultCellContentView.Model(
      textContentModel: textContentModel,
      image: .image(type.icon, tinColor: .Icon.secondary, backgroundColor: .Background.contentTint)
    )
    var statusModel: TransactionCellContentView.TransactionCellStatusView.Model?
    if let status = status {
      statusModel = .init(status: status.attributed(with: .body2, color: .Accent.orange))
    }
    
    var commentModel: TransactionCellContentView.TransactionCellCommentView.Model?
    if let comment = comment {
      commentModel = .init(comment: comment.attributed(with: .body2, color: .Text.primary))
    }
    
    let transactionModel = TransactionCellContentView.Model(
      defaultContentModel: contentModel,
      statusModel: statusModel,
      commentModel: commentModel)
    
    return transactionModel
  }
}

extension ActivityEventViewModel.ActionViewModel.ActionType {
  var icon: UIImage? {
    switch self {
    case .sent:
      return .Icons.Transaction.sent
    case .receieved:
      return .Icons.Transaction.receieved
    case .spam:
      return .Icons.Transaction.spam
    case .bounced:
      return .Icons.Transaction.bounced
    case .subscribed:
      return .Icons.Transaction.subscribed
    case .unsubscribed:
      return .Icons.Transaction.unsubscribed
    case .walletInitialized:
      return .Icons.Transaction.walletInitialized
    case .nftCollectionCreation:
      return .Icons.Transaction.nftCollectionCreation
    case .nftCreation:
      return .Icons.Transaction.nftCreation
    case .removalFromSale:
      return .Icons.Transaction.removalFromSale
    case .nftPurchase:
      return .Icons.Transaction.nftPurchase
    case .bid:
      return .Icons.Transaction.bid
    case .putUpForAuction:
      return .Icons.Transaction.putUpForAuction
    case .endOfAuction:
      return .Icons.Transaction.endOfAuction
    case .putUpForSale:
      return .Icons.Transaction.putUpForSale
    }
  }
  
  var title: String {
    switch self {
    case .sent:
      return "Sent"
    case .receieved:
      return "Received"
    case .spam:
      return "Spam"
    case .bounced:
      return "Bounced"
    case .subscribed:
      return "Received"
    case .unsubscribed:
      return "Unsubscribed"
    case .walletInitialized:
      return "Wallet initialized"
    case .nftCollectionCreation:
      return "NFT сollection creation"
    case .nftCreation:
      return "NFT creation"
    case .removalFromSale:
      return "Removal from sale"
    case .nftPurchase:
      return "NFT purchase"
    case .bid:
      return "Bid"
    case .putUpForAuction:
      return "Put up for auction"
    case .endOfAuction:
      return "End of auction"
    case .putUpForSale:
      return "Put up for sale"
    }
  }
  
  var amountColor: UIColor {
    switch self {
    case .sent,
        .subscribed,
        .unsubscribed,
        .walletInitialized,
        .nftCollectionCreation,
        .nftCreation,
        .removalFromSale,
        .nftPurchase, .bid,
        .putUpForAuction,
        .endOfAuction,
        .putUpForSale:
      return .Text.primary
    case .receieved, .bounced:
      return .Accent.green
    case .spam:
      return .Text.tertiary
    }
  }
}
