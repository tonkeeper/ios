import UIKit
import TKUIKit
import TKCoordinator
import SignerCore
import SignerLocalize

final class EnterPasswordCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didEnterPassword: (() -> Void)?
  var didSignOut: (() -> Void)?
  
  private let assembly: SignerCore.Assembly
  
  init(router: NavigationControllerRouter, assembly: SignerCore.Assembly) {
    self.assembly = assembly
    super.init(router: router)
  }

  override func start() {
    openEnterPassword()
  }
}

private extension EnterPasswordCoordinator {
  func openEnterPassword() {
    let configurator = EnterPasswordPasswordInputViewModelConfigurator(
      mnemonicsRepository: assembly.repositoriesAssembly.mnemonicsRepository(),
      title: SignerLocalize.Password.Confirmation.title
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak self] _ in
      self?.didEnterPassword?()
    }
    
//    let signOutButton = TKButton.titleHeaderButton()
//    signOutButton.configure(
//      model: .init(
//        contentModel: .init(title: "Sign Out"),
//        action: { [weak self] in
//          self?.openSignOutAlert()
//        }
//      )
//    )
//    module.view.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: signOutButton)
    
    router.push(viewController: module.view,
                onPopClosures: {})
  }
  
  func openSignOutAlert() {
    let alertViewController = UIAlertController(
      title: "Sign Out?",
      message: "This will erase keys to the wallet. Make sure you have backed up your secret recovery phrase.",
      preferredStyle: .alert
    )
    alertViewController.addAction(
      UIAlertAction(title: "Cancel",
                    style: .default)
    )
    alertViewController.addAction(
      UIAlertAction(title: "Sign Out",
                    style: .destructive,
                    handler: { [weak self] _ in
                      self?.didSignOut?()
                    })
    )
    router.rootViewController.present(alertViewController, animated: true)
  }
}
