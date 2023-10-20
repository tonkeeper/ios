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
                             subamount: String?,
                             time: String?,
                             status: String?,
                             comment: String? = nil,
                             collectible: ActivityEventViewModel.ActionViewModel.CollectibleViewModel? = nil) -> TransactionCellContentView.Model {
    let textContentModel = DefaultCellTextContentView.Model(
      title: type.title,
      amount: amount?.attributed(with: .label1, alignment: .right, color: type.amountColor),
      subamount: subamount?.attributed(with: .label1, alignment: .right, color: type.subamountColor),
      topLeftDescriptionValue: subtitle,
      topLeftDescriptionSubvalue: nil,
      topRightDescriptionValue: time
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
    
    var nftModel: TransactionCellContentView.TransactionCellNFTView.Model?
    if let collectible = collectible {
      nftModel = .init(image: .with(image: collectible.image), name: collectible.name, collectionName: collectible.collectionName)
    }
    
    let transactionModel = TransactionCellContentView.Model(
      defaultContentModel: contentModel,
      statusModel: statusModel,
      commentModel: commentModel,
      nftModel: nftModel)
    
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
    case .sentAndReceieved:
      return .Icons.Transaction.receieved
    case .mint:
      return .Icons.Transaction.receieved
    case .depositStake:
      return .Icons.Transaction.sent
    case .withdrawStake:
      return .Icons.Transaction.sent
    case .jettonSwap:
      return .Icons.Transaction.swap
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
    case .contractExec:
      return .Icons.Transaction.smartContractExec
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
    case .sentAndReceieved:
      return "Sent and received"
    case .mint:
      return "Received"
    case .depositStake:
      return "Stake"
    case .withdrawStake:
      return "Stake"
    case .jettonSwap:
      return "Swap"
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
    case .contractExec:
      return "Call contract"
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
        .sentAndReceieved,
        .depositStake,
        .subscribed,
        .unsubscribed,
        .walletInitialized,
        .nftCollectionCreation,
        .nftCreation,
        .removalFromSale,
        .nftPurchase, 
        .bid,
        .putUpForAuction,
        .endOfAuction,
        .contractExec,
        .putUpForSale:
      return .Text.primary
    case .receieved, .bounced, .mint, .withdrawStake, .jettonSwap:
      return .Accent.green
    case .spam:
      return .Text.tertiary
    }
  }
  
  var subamountColor: UIColor {
    switch self {
    case .sentAndReceieved:
      return .Accent.green
    case .jettonSwap:
      return .Text.primary
    default:
      return .Text.primary
    }
  }
}
