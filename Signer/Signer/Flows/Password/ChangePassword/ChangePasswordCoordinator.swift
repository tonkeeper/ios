import UIKit
import TKUIKit
import TKCoordinator
import SignerCore
import SignerLocalize

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
      mnemonicsRepository: assembly.repositoriesAssembly.mnemonicsRepository(),
      title: SignerLocalize.Password.Change.EnterCurrent.title
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak self] password in
      self?.openSetNewPassword(oldPassword: password)
    }
    
    module.view.setupLeftCloseButton { [weak self, weak view = module.view] in
      view?.dismiss(animated: true) { [weak self] in
        self?.didFinish?()
      }
    }

    router.push(viewController: module.view,
                onPopClosures: {})
  }
  
  func openSetNewPassword(oldPassword: String) {
    let coordinator = CreatePasswordCoordinator(router: router,
                                                showKeyboardOnAppear: true,
                                                showAsRoot: true,
                                                isChangePassword: true)
    coordinator.didCreatePassword = { [weak self] password in
      self?.setNewPassword(oldPassword: oldPassword, newPassword: password)
    }
    
    coordinator.didFinish = { [weak self, unowned coordinator] in
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func setNewPassword(oldPassword: String, newPassword: String) {
    let mnemonicsRepository = assembly.repositoriesAssembly.mnemonicsRepository()
    do {
      try mnemonicsRepository.changePassword(oldPassword: oldPassword, newPassword: newPassword)
      didFinish?()
      ToastPresenter.showToast(configuration: .Signer.passwordChanged)
    } catch {
      ToastPresenter.showToast(configuration: .Signer.passwordChangeFailed)
    }
  }
}
