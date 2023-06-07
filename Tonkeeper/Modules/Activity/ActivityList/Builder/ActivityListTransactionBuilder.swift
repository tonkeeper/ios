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
                             time: String) -> ActivityListTransactionCell.Model {
    .init(icon: type.icon,
          name: type.title,
          subtitle: "EQAK…MALX",
          amount: amount.attributed(with: .label1, alignment: .left, color: type.amountColor),
          time: time)
  }
}
