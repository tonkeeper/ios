//
//  StakeInfoAssembly.swift
//
//
//  Created by Semyon on 18/05/2024.
//

import Foundation
import TKCore
import KeeperCore

struct StakeInfoAssembly {
  private init() {}
  static func module() -> MVVMModule<StakeInfoViewController, StakeInfoModuleOutput, StakeInfoModuleInput> {
    let viewModel = StakeInfoViewModelImplementation()
    let viewController = StakeInfoViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}
