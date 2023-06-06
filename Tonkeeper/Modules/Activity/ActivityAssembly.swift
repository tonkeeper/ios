//
//  ActivityAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 23.5.23..
//

import UIKit

struct ActivityAssembly {
  private let receiveAssembly: ReceiveAssembly
  
  init(receiveAssembly: ReceiveAssembly) {
    self.receiveAssembly = receiveAssembly
  }
  
  func activityRootModule(output: ActivityRootModuleOutput) -> Module<UIViewController, Void> {
    let presenter = ActivityRootPresenter()
    presenter.output = output
    
    let emptyModule = activityEmptyModule(output: presenter)
    presenter.emptyInput = emptyModule.input
    
    let viewController = ActivityRootViewController(
      presenter: presenter,
      emptyViewController: emptyModule.view
    )
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
  
  func receieveCoordinator(output: ReceiveCoordinatorOutput) -> ReceiveCoordinator {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = ReceiveCoordinator(router: router,
                                         assembly: receiveAssembly)
    coordinator.output = output
    return coordinator
  }
}

private extension ActivityAssembly {
  func activityEmptyModule(output: ActivityEmptyModuleOutput) -> Module<ActivityEmptyViewController, ActivityEmptyModuleInput> {
    let presenter = ActivityEmptyPresenter()
    presenter.output = output
    
    let viewController = ActivityEmptyViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
