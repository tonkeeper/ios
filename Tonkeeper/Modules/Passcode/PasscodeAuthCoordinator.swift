//
//  PasscodeAuthCoordinator.swift
//  Tonkeeper
//
//  Created by Grigory on 10.7.23..
//

import UIKit
import WalletCoreKeeper

protocol PasscodeAuthCoordinatorOutput: AnyObject {
  func createPasscodeCoordinatorDidStartBiometry(_ coordinator: PasscodeAuthCoordinator)
  func createPasscodeCoordinatorDidFinishBiometry(_ coordinator: PasscodeAuthCoordinator)
  func createPasscodeCoordinatorDidAuth(_ coordinator: PasscodeAuthCoordinator)
  func createPasscodeCoordinatorDidLogout(_ coordinator: PasscodeAuthCoordinator)
}

final class PasscodeAuthCoordinator: Coordinator<NavigationRouter> {
  
  weak var output: PasscodeAuthCoordinatorOutput?
  
  let assembly: PasscodeAssembly
  
  init(router: NavigationRouter,
       assembly: PasscodeAssembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openPasscodeAuth()
  }
}

private extension PasscodeAuthCoordinator {
  func openPasscodeAuth(){
    let configurator = assembly.passcodeAuthConfigurator()
    configurator.didFinish = { [weak self] _ in
      guard let self = self else { return }
      self.output?.createPasscodeCoordinatorDidAuth(self)
    }
    configurator.didFailed = {}
    configurator.didStartBiometry = { [weak self] in
      guard let self = self else { return }
      self.output?.createPasscodeCoordinatorDidStartBiometry(self)
    }
    configurator.didFinishBiometry = { [weak self] isSuccess in
      guard let self = self else { return }
      if isSuccess {
        self.output?.createPasscodeCoordinatorDidAuth(self)
      }
      self.output?.createPasscodeCoordinatorDidFinishBiometry(self)
    }
    
    let module = assembly.passcodeInputAssembly(output: self, configurator: configurator)
    let logoutButton = TKButton(configuration: .secondarySmall)
    logoutButton.configure(model: TKButton.Model(title: .string("Log out")))
    logoutButton.addTarget(self, action: #selector(didTapLogout), for: .touchUpInside)
    module.view.viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: logoutButton)
    
    
    let containerViewController = UIViewController()
    let navigationController = NavigationController()
    navigationController.configureDefaultAppearance()
    containerViewController.addChild(navigationController)
    containerViewController.view.addSubview(navigationController.view)
    navigationController.didMove(toParent: containerViewController)
    
    navigationController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      navigationController.view.topAnchor.constraint(equalTo: containerViewController.view.topAnchor),
      navigationController.view.leftAnchor.constraint(equalTo: containerViewController.view.leftAnchor),
      navigationController.view.bottomAnchor.constraint(equalTo: containerViewController.view.bottomAnchor),
      navigationController.view.rightAnchor.constraint(equalTo: containerViewController.view.rightAnchor)
    ])
    
    navigationController.setViewControllers([module.view], animated: false)
    
    initialPresentable = containerViewController
    router.setPresentables([(containerViewController, nil)])
  }
  
  @objc
  func didTapLogout() {
    let actions = [
      UIAlertAction(title: .logoutCancelButtonTitle, style: .cancel),
      UIAlertAction(title: .logoutLogoutButtonTitle, style: .destructive, handler: { [weak self] _ in
        guard let self = self else { return }
        self.assembly.walletCoreAssembly.logoutController().logout()
        self.output?.createPasscodeCoordinatorDidLogout(self)
      })
    ]
    
    let alertController = UIAlertController(
      title: .logoutTitle,
      message: .logoutDescription,
      preferredStyle: .alert)
    alertController.overrideUserInterfaceStyle = .dark
    actions.forEach {
      alertController.addAction($0)
    }
    initialPresentable?.present(alertController, animated: true)
  }
}

// MARK: - PasscodeInputModuleOutput

extension PasscodeAuthCoordinator: PasscodeInputModuleOutput {
  
}

private extension String {
  static let logoutTitle = "Log out?"
  static let logoutDescription = "This will erase keys to the wallet. Make sure you have backed up your secret recovery phrase."
  static let logoutCancelButtonTitle = "Cancel"
  static let logoutLogoutButtonTitle = "Log out"
}
