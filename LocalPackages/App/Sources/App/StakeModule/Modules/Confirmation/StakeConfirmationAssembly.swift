//
//  StakeConfirmationAssembly.swift
//
//
//  Created by Semyon on 17/05/2024.
//

import Foundation
import TKCore
import KeeperCore

struct StakeConfirmationAssembly {
  private init() {}
  static func module() -> MVVMModule<StakeConfirmationViewController, StakeConfirmationModuleOutput, StakeConfirmationModuleInput> {
    let viewModel = StakeConfirmationViewModelImplementation()
    let viewController = StakeConfirmationViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
