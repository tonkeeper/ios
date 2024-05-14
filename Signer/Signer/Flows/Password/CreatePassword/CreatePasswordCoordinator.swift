import UIKit
import TKCoordinator
import SignerLocalize

final class CreatePasswordCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  var didCreatePassword: ((String) -> Void)?
  
  private let showKeyboardOnAppear: Bool
  private let showAsRoot: Bool
  private let isChangePassword: Bool
  
  init(router: NavigationControllerRouter,
       showKeyboardOnAppear: Bool,
       showAsRoot: Bool,
       isChangePassword: Bool) {
    self.showKeyboardOnAppear = showKeyboardOnAppear
    self.showAsRoot = showAsRoot
    self.isChangePassword = isChangePassword
    super.init(router: router)
  }
  
  override func start() {
    openEnterPassword()
  }
}

private extension CreatePasswordCoordinator {
  func openEnterPassword() {
    let configurator = CreatePasswordPasswordInputViewModelConfigurator(
      showKeyboardWhileAppear: showKeyboardOnAppear,
      title: isChangePassword ? SignerLocalize.Password.Change.EnterNew.title : SignerLocalize.Password.Create.title
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.output.didEnterPassword = { [weak self] password in
      self?.openReenterPassword(password: password)
    }
    
    if showAsRoot {
      module.view.setupLeftCloseButton { [weak self, weak view = module.view] in
        view?.dismiss(animated: true, completion: { [weak self] in
          self?.didFinish?()
        })
      }
      router.setViewControllers([(module.view, nil)])
    } else {
      module.view.setupBackButton()
      router.push(viewController: module.view,
                  onPopClosures: { [weak self] in
        self?.didFinish?()
      })
    }
  }
  
  func openReenterPassword(password: String) {
    let configurator = ReenterPasswordPasswordInputViewModelConfigurator(
      title: isChangePassword ? SignerLocalize.Password.Change.ReenterNew.title	 : SignerLocalize.Password.Reenter.title,
      password: password
    )
    let module = PasswordInputModuleAssembly.module(configurator: configurator)
    module.view.setupBackButton()
    module.output.didEnterPassword = { [weak self] password in
      self?.didCreatePassword?(password)
    }
    router.push(viewController: module.view)
  }
}
