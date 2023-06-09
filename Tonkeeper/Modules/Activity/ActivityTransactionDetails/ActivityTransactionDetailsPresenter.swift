//
//  ActivityTransactionDetailsActivityTransactionDetailsPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import Foundation

final class ActivityTransactionDetailsPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ActivityTransactionDetailsViewInput?
  weak var output: ActivityTransactionDetailsModuleOutput?
}

// MARK: - ActivityTransactionDetailsPresenterIntput

extension ActivityTransactionDetailsPresenter: ActivityTransactionDetailsPresenterInput {
  func viewDidLoad() {
    updateWithMockConfiguration()
  }
}

// MARK: - ActivityTransactionDetailsModuleInput

extension ActivityTransactionDetailsPresenter: ActivityTransactionDetailsModuleInput {}

// MARK: - Private

private extension ActivityTransactionDetailsPresenter {
  func updateWithMockConfiguration() {
    let configuration = ActivityTransactionDetailsBuilder.configuration(
      title: "- 50 TON",
      description: "$ 84.06",
      fixDescription: "Sent on 18 May 2023, 17:01",
      recipientAddress: "EQDv...eper",
      transaction: "e5abaca6…d8552to4",
      fee: "0.01 TON",
      feeFiat: "$ 0.02",
      message: "Thanks!",
      tapAction: { [weak self] _ in
        self?.output?.didTapViewInExplorer()
      }
    )
    
    viewInput?.update(with: configuration)
  }
}
