import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKLocalize

protocol PasscodeValidator {
  func validate(passcode: String) async -> PasscodeInputValidationResult
}

final class PasscodeInputCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didInputPasscode: ((String) -> Void)?
  var didCancel: (() -> Void)?
  
  private let validator: PasscodeValidator
    
  init(router: NavigationControllerRouter,
       validator: PasscodeValidator) {
    self.validator = validator
    super.init(router: router)
    router.rootViewController.modalPresentationStyle = .fullScreen
    router.rootViewController.modalTransitionStyle = .crossDissolve
  }
  
  override func start() {
    openPasscode()
  }
}

private extension PasscodeInputCoordinator {
  func openPasscode() {
    let navigationController = TKNavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    
    let passcodeInputModule = PasscodeInputAssembly.module(
      title: TKLocales.Passcode.enter
    )
    
    let passcodeModule = PasscodeAssembly.module(
      navigationController: navigationController,
      isBiometryTurnedOn: false
    )
    
    passcodeInputModule.output.didFinishInput = { [weak self] passcode in
      guard let self else { return .failed }
      await MainActor.run {
        passcodeModule.view.customView.isUserInteractionEnabled = false
      }
      let result = await Task {
        await self.validator.validate(passcode: passcode)
      }.value
      await MainActor.run {
        passcodeModule.view.customView.isUserInteractionEnabled = true
      }
      return result
    }
    
    passcodeInputModule.output.didEnterPasscode = { [weak self] passcode in
      self?.didInputPasscode?(passcode)
    }

    passcodeModule.output.didTapBackspace = {
      passcodeInputModule.input.didTapBackspace()
    }
    
    passcodeModule.output.didTapDigit = { digit in
      passcodeInputModule.input.didTapDigit(digit)
    }
    
    passcodeModule.output.didTapBiometry = {
      passcodeInputModule.input.didTapBiometry()
    }
    
    passcodeModule.view.setupLeftCloseButton { [weak self] in
      self?.didCancel?()
    }
    
    navigationController.pushViewController(passcodeInputModule.viewController, animated: false)
    
    router.push(viewController: passcodeModule.view)
  }
}

extension PasscodeInputCoordinator {
  static func confirmationCoordinator(router: NavigationControllerRouter, 
                                      repositoriesAssembly: KeeperCore.RepositoriesAssembly) -> PasscodeInputCoordinator {
    let validator = PasscodeConfirmationValidator(
      mnemonicsRepository: repositoriesAssembly.mnemonicsRepository()
    )
    return PasscodeInputCoordinator(router: router, validator: validator)
  }
}

extension PasscodeInputCoordinator {
  static func present<ParentRouterViewController: UIViewController>(parentCoordinator: Coordinator,
                                                                    parentRouter: ContainerViewControllerRouter<ParentRouterViewController>,
                                                                    repositoriesAssembly: KeeperCore.RepositoriesAssembly,
                                                                    onCancel: @escaping () -> Void,
                                                                    onInput: @escaping (String) -> Void) {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    navigationController.modalPresentationStyle = .fullScreen
    navigationController.modalTransitionStyle = .crossDissolve
    
    let coordinator = confirmationCoordinator(
      router: NavigationControllerRouter(
        rootViewController: navigationController
      ),
      repositoriesAssembly: repositoriesAssembly
    )
    
    coordinator.didCancel = { [weak coordinator, weak parentCoordinator] in
      parentRouter.dismiss(animated: true) {
        parentCoordinator?.removeChild(coordinator)
        onCancel()
      }
    }
    
    coordinator.didInputPasscode = { [weak coordinator, weak parentCoordinator] passcode in
      parentRouter.dismiss(animated: true) {
        parentCoordinator?.removeChild(coordinator)
        onInput(passcode)
      }
    }

    parentCoordinator.addChild(coordinator)
    coordinator.start()
    
    parentRouter.present(
      navigationController,
      animated: true)
  }
}
