//
//  ActivityListTransactionBuilder.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import Foundation

struct ActivityListTransactionBuilder {
  func buildTransactionModel(type: TransactionType,
                             subtitle: String,
                             amount: String,
                             time: String,
                             isFailed: Bool = false,
                             comment: String? = nil) -> TransactionCellContentView.Model {
    
    let textContentModel = DefaultCellTextContentView.Model(
      leftTopTitle: type.title,
      leftTopRightTitle: nil,
      rightTopTitle: amount.attributed(with: .label1, alignment: .left, color: type.amountColor),
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
    if isFailed {
      statusModel = .init(status: "Failed".attributed(with: .body2, color: .Accent.orange))
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
