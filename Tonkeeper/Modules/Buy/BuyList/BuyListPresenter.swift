//
//  BuyListBuyListPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 09/06/2023.
//

import Foundation

final class BuyListPresenter {
  
  // MARK: - Module
  
  weak var viewInput: BuyListViewInput?
  weak var output: BuyListModuleOutput?
}

// MARK: - BuyListPresenterIntput

extension BuyListPresenter: BuyListPresenterInput {
  func viewDidLoad() {}
}

// MARK: - BuyListModuleInput

extension BuyListPresenter: BuyListModuleInput {}

// MARK: - Private

private extension BuyListPresenter {}
