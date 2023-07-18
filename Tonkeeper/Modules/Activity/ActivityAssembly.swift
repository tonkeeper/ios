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
    
    let listModule = activityListModule(output: presenter)
    presenter.listInput = listModule.input
    
    let viewController = ActivityRootViewController(
      presenter: presenter,
      emptyViewController: emptyModule.view,
      listViewController: listModule.view
    )
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
  }
  
  func receieveCoordinator(output: ReceiveCoordinatorOutput,
                           address: String) -> ReceiveCoordinator {
    let navigationController = NavigationController()
    navigationController.configureTransparentAppearance()
    let router = NavigationRouter(rootViewController: navigationController)
    let coordinator = receiveAssembly.coordinator(
      router: router,
      flow: .any)
    coordinator.output = output
    return coordinator
  }
  
  func activityTransactionDetails(output: ActivityTransactionDetailsModuleOutput) -> Module<ActivityTransactionDetailsViewController, Void> {
    let presenter = ActivityTransactionDetailsPresenter()
    presenter.output = output
    
    let viewController = ActivityTransactionDetailsViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: Void())
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
  
  func activityListModule(output: ActivityListModuleOutput) -> Module<ActivityListViewController, ActivityListModuleInput> {
    let presenter = ActivityListPresenter(transactionBuilder: ActivityListTransactionBuilder())
    presenter.output = output
    
    let viewController = ActivityListViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return Module(view: viewController, input: presenter)
  }
}
