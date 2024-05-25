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
    
    let singOutButton = TKButton(configuration: .titleHeaderButtonConfiguration(category: .secondary))
    singOutButton.configuration.padding.top = 4
    singOutButton.configuration.padding.bottom = 4
    singOutButton.configuration.content = TKButton.Configuration.Content(
      title: .plainString(
        SignerLocalize.SignOut.Button.title
      )
    )
    singOutButton.configuration.action = { [weak self] in
      self?.openSignOutAlert()
    }
    module.view.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: singOutButton)
    
    router.push(viewController: module.view,
                onPopClosures: {})
  }
  
  func openSignOutAlert() {
    let alertViewController = UIAlertController(
      title: SignerLocalize.SignOut.Alert.title,
      message: SignerLocalize.SignOut.Alert.caption,
      preferredStyle: .alert
    )
    alertViewController.addAction(
      UIAlertAction(title: SignerLocalize.Actions.cancel,
                    style: .default)
    )
    alertViewController.addAction(
      UIAlertAction(title: SignerLocalize.SignOut.Alert.Button.sign_out,
                    style: .destructive,
                    handler: { [weak self] _ in
                      self?.didSignOut?()
                    })
    )
    router.rootViewController.present(alertViewController, animated: true)
  }
}
