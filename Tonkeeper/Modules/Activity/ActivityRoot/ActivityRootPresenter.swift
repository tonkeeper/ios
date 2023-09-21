//
//  ActivityRootActivityRootPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 06/06/2023.
//

import Foundation
import TonSwift
import WalletCore

final class ActivityRootPresenter {
  
  // MARK: - Module
  
  weak var viewInput: ActivityRootViewInput?
  weak var output: ActivityRootModuleOutput?
  
  weak var emptyInput: ActivityEmptyModuleInput?
  weak var listInput: ActivityListModuleInput?
  
  // MARK: - Dependencies
  
  private let activityController: ActivityController
  
  init(activityController: ActivityController) {
    self.activityController = activityController
  }
}

// MARK: - ActivityRootPresenterIntput

extension ActivityRootPresenter: ActivityRootPresenterInput {
  func viewDidLoad() {
    viewInput?.updateTitle("Activity")
  }
}

// MARK: - ActivityRootModuleInput

extension ActivityRootPresenter: ActivityRootModuleInput {}

// MARK: - ActivityEmptyModuleOutput

extension ActivityRootPresenter: ActivityEmptyModuleOutput {
  func didTapReceiveButton() {
    output?.didTapReceiveButton()
  }
}

// MARK: - ActivityListModuleOutput

extension ActivityRootPresenter: ActivityListModuleOutput {
  func didSelectTransaction(in section: Int, at index: Int) {
    output?.didSelectTransaction()
  }
  
  func activityListNoEvents(_ activityList: ActivityListModuleInput) {
    viewInput?.showEmptyState()
  }
  
  func activityListHasEvents(_ activityList: ActivityListModuleInput) {
    viewInput?.showList()
  }
}

// MARK: - ActivityListModuleCollectibleOutput

extension ActivityRootPresenter: ActivityListModuleCollectibleOutput {
  func didSelectCollectible(with address: Address) {
    if activityController.isNeedToLoadNFT(with: address) {
      ToastController.showToast(configuration: .loading)
      Task {
        do {
          try await activityController.loadNFT(with: address)
          await MainActor.run {
            ToastController.hideToast()
            output?.didSelectCollectible(address: address)
          }
        } catch {
          await MainActor.run {
            ToastController.hideToast()
            ToastController.showToast(configuration: .failed)
          }
        }
      }
    } else {
      output?.didSelectCollectible(address: address)
    }
  }
}

// MARK: - Private

private extension ActivityRootPresenter {}
