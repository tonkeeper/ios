//
//  ReceiveReceivePresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 05/06/2023.
//

import Foundation

final class ReceivePresenter {
  
  // MARK: - Module
  
  weak var viewInput: ReceiveViewInput?
  weak var output: ReceiveModuleOutput?
}

// MARK: - ReceivePresenterIntput

extension ReceivePresenter: ReceivePresenterInput {
  func viewDidLoad() {}
}

// MARK: - ReceiveModuleInput

extension ReceivePresenter: ReceiveModuleInput {}

// MARK: - Private

private extension ReceivePresenter {}
