//
//  File.swift
//  
//
//  Created by Semyon on 18/05/2024.
//

import Foundation
import TKCore
import KeeperCore

struct StakeOptionsAssembly {
  private init() {}
  static func module() -> MVVMModule<StakeOptionsViewController, StakeOptionsModuleOutput, StakeOptionsModuleInput> {
    let viewModel = StakeOptionsViewModelImplementation()
    let viewController = StakeOptionsViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: viewModel)
  }
}

