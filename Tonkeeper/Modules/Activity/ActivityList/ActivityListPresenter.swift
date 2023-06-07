//
//  ActivityListActivityListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation

final class ActivityListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ActivityListViewInput?
  weak var output: ActivityListModuleOutput?
  
  // MARK: - Dependencies
  
  private let transactionBuilder: ActivityListTransactionBuilder
  
  init(transactionBuilder: ActivityListTransactionBuilder) {
    self.transactionBuilder = transactionBuilder
  }
}

// MARK: - ActivityListPresenterIntput

extension ActivityListPresenter: ActivityListPresenterInput {
  func viewDidLoad() {
    loadFakeTransactions()
  }
}

// MARK: - ActivityListModuleInput

extension ActivityListPresenter: ActivityListModuleInput {}

// MARK: - Private

private extension ActivityListPresenter {
  func loadFakeTransactions() {
    
    let items1: [ActivityListTransactionCell.Model] = [
      transactionBuilder.buildTransactionModel(type: .sent,
                                               subtitle: "EQAK…MALX",
                                               amount: "− 400.00 TON",
                                               time: "17:32", comment: "Never gonna give you up. Never gonna let you down"),
      transactionBuilder.buildTransactionModel(type: .receieved,
                                               subtitle: "EQAK…MALX",
                                               amount: "+ 400.00 TON",
                                               time: "17:32",
                                               isFailed: true,
                                               comment: "Short Message"),
      transactionBuilder.buildTransactionModel(type: .walletInitialized,
                                               subtitle: "EQAK…MALX",
                                               amount: "-",
                                               time: "17:32"),
    ]
    
    let items2: [ActivityListTransactionCell.Model] = [
      transactionBuilder.buildTransactionModel(type: .receieved,
                                               subtitle: "EQAK…MALX",
                                               amount: "+ 400.00 TON",
                                               time: "17:32")
    ]
    
    let items3 = (0..<500).map { _ in
      transactionBuilder.buildTransactionModel(type: .nftPurchase,
                                               subtitle: "EQAK…MALX",
                                               amount: "+ 400.00 TON",
                                               time: "04:20",
                                               comment: "Short Message")
    }

    let sections: [ActivityListSection] = [
      .init(type: .date, items: [ActivityListDateCell.Model(date: "5 June")]),
      .init(type: .transaction, items: items1),
      .init(type: .transaction, items: items2),
      .init(type: .date, items: [ActivityListDateCell.Model(date: "3 June")]),
      .init(type: .transaction, items: items3)
    ]
    
    viewInput?.updateSections(sections)
  }
}
