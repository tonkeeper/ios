//
//  BuyListBuyListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import Foundation
import WalletCore

final class BuyListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: BuyListViewInput?
  weak var output: BuyListModuleOutput?
  
  // MARK: - Dependencies
  
  private let fiatMethodsController: FiatMethodsController
  private let buyListServiceBuilder: BuyListServiceBuilder
  
  init(fiatMethodsController: FiatMethodsController,
       buyListServiceBuilder: BuyListServiceBuilder) {
    self.fiatMethodsController = fiatMethodsController
    self.buyListServiceBuilder = buyListServiceBuilder
  }
}

// MARK: - BuyListPresenterIntput

extension BuyListPresenter: BuyListPresenterInput {
  func viewDidLoad() {
    updateFiatMethods()
  }
  
  func didSelectServiceAt(indexPath: IndexPath) {
      
  }
}

// MARK: - BuyListModuleInput

extension BuyListPresenter: BuyListModuleInput {}

// MARK: - Private

private extension BuyListPresenter {
  func updateFiatMethods() {
    Task {
      do {
        let cachedViewModels = try await fiatMethodsController.getFiatMethods()
        await MainActor.run {
          viewInput?.updateSections(cachedViewModels.map {
            let cellModels = $0.map { buyListServiceBuilder.buildServiceModel(viewModel: $0) }
            return BuyListSection(type: .services, items: cellModels)
          })
        }
      } catch {}
      do {
        let loadedViewModels = try await fiatMethodsController.loadFiatMethods()
        await MainActor.run {
          viewInput?.updateSections(loadedViewModels.map {
            let cellModels = $0.map { buyListServiceBuilder.buildServiceModel(viewModel: $0) }
            return BuyListSection(type: .services, items: cellModels)
          })
        }
      }
    }
  }
}
