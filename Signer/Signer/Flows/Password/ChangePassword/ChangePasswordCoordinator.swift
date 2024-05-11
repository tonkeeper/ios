import UIKit
import TKUIKit
import TKCoordinator
import SignerCore

final class ChangePasswordCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  
  private let assembly: SignerCore.Assembly
  
  init(router: NavigationControllerRouter, assembly: SignerCore.Assembly) {
    self.assembly = assembly
    super.init(router: router)
  }

  override func start() {
    openEnterCurrentPassword()
  }
}

private extension ChangePasswordCoordinator {
  func openEnterCurrentPassword() {
    let configurator = EnterPasswordPasswordInputViewModelConfigurator(
      passwordRepository: assembly.repositoriesAssembly.passwordRepository()
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak self] _ in
      self?.openSetNewPassword()
    }
    
    module.view.setupLeftCloseButton { [weak self, weak view = module.view] in
      view?.dismiss(animated: true) { [weak self] in
        self?.didFinish?()
      }
    }

    router.push(viewController: module.view,
                onPopClosures: {})
  }
  
  func openSetNewPassword() {
    let coordinator = CreatePasswordCoordinator(router: router,
                                                showKeyboardOnAppear: true,
                                                showAsRoot: true)
    coordinator.didCreatePassword = { [weak self] password in
      self?.setNewPassword(password)
    }
    
    coordinator.didFinish = { [weak self, unowned coordinator] in
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func setNewPassword(_ newPassword: String) {
    let createPasswordController = assembly.passwordAssembly.passwordCreateController()
    do {
      try createPasswordController.createPassword(newPassword)
      didFinish?()
      ToastPresenter.showToast(configuration: .Signer.passwordChanged)
    } catch {}
  }
}
