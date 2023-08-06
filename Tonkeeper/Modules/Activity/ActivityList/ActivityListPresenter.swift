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
    loadInitialEvents()
  }
  
  func didSelectTransactionAt(indexPath: IndexPath) {
    output?.didSelectTransaction(in: indexPath.section, at: indexPath.item)
  }
}

// MARK: - ActivityListModuleInput

extension ActivityListPresenter: ActivityListModuleInput {}

// MARK: - Private

private extension ActivityListPresenter {
  func loadInitialEvents() {
    loadFakeTransactions()
  }
  
  func loadFakeTransactions() {
    let item1 = transactionBuilder.buildTransactionModel(type: .sent,
                                                         subtitle: "EQAK…MALX",
                                                         amount: "− 400.00 TON",
                                                         time: "17:32", comment: "Never gonna give you up. Never gonna let you down")
    
    let subs2 = [
      transactionBuilder.buildTransactionModel(type: .receieved, subtitle: "EQAK…MALX", amount: "+ 300.00 TON", time: "17:10", comment: "Hui pizda djigurda"),
      transactionBuilder.buildTransactionModel(type: .spam, subtitle: "EQAK…MALX", amount: "+ 300.00 TON", time: "17:10"),
      transactionBuilder.buildTransactionModel(type: .walletInitialized, subtitle: "EQAK…MALX", amount: "+ 300.00 TON", time: "17:10"),
    ]
    
    let subs3 = [
      transactionBuilder.buildTransactionModel(type: .sent, subtitle: "EQAK…MALX", amount: "+ 300.00 TON", time: "17:10", comment: "Hui pizda djigurda"),
      transactionBuilder.buildTransactionModel(type: .endOfAuction, subtitle: "EQAK…MALX", amount: "+ 300.00 TON", time: "17:10"),
    ]
    
    let items3 = (0..<500).map { _ in
      ActivityListCompositionTransactionCell.Model(childTransactionModels: [
        transactionBuilder.buildTransactionModel(type: .nftPurchase,
                                               subtitle: "EQAK…MALX",
                                               amount: "+ 400.00 TON",
                                               time: "04:20",
                                               comment: "Short Message"),
        transactionBuilder.buildTransactionModel(type: .nftPurchase,
                                               subtitle: "EQAK…MALX",
                                               amount: "+ 400.00 TON",
                                               time: "04:20",
                                               comment: nil)
        ])
    }

    let sections: [ActivityListSection] = [
      .init(items: [ActivityListTransactionCell.Model(transactionModel: item1)]),
      .init(items: [ActivityListCompositionTransactionCell.Model(childTransactionModels: subs2)]),
      .init(items: [ActivityListCompositionTransactionCell.Model(childTransactionModels: subs3)]),
      .init(items: items3)
    ]
    viewInput?.updateSections(sections)
  }
}
