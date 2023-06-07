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
      .init(icon: nil,
            name: "Sent",
            subtitle: "EQAK…MALX",
            amount: "− 400.00 TON".attributed(with: .label1,
                                              alignment: .right,
                                              color: .Text.primary),
            time: "17:32"),
      .init(icon: nil,
            name: "Received",
            subtitle: "EQAK…MALX",
            amount: "+ 400.00 SNT".attributed(with: .label1,
                                              alignment: .right,
                                              color: .Accent.green),
            time: "17:32")
    ]
    
    let items2: [ActivityListTransactionCell.Model] = [
      .init(icon: nil,
            name: "Sent",
            subtitle: "EQAK…MALX",
            amount: "− 400.00 TON".attributed(with: .label1,
                                              alignment: .right,
                                              color: .Text.primary),
            time: "17:32")
    ]
    
    let items3: [ActivityListTransactionCell.Model] = [
      .init(icon: nil,
            name: "Sent",
            subtitle: "EQAK…MALX",
            amount: "− 400.00 TON".attributed(with: .label1,
                                              alignment: .right,
                                              color: .Text.primary),
            time: "17:32")
    ]
    
    let sections: [ActivityListSection] = [
      .init(type: .transaction, items: items1),
      .init(type: .transaction, items: items2),
      .init(type: .transaction, items: items3)
    ]
    
    viewInput?.updateSections(sections)
  }
}
