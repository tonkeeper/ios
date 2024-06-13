import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKLocalize

final class PasscodeCreateCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didCreatePasscode: ((String) -> Void)?
  var didCancel: (() -> Void)?
  
  private let passcodeNavigationController = UINavigationController()
  private var passcodeInputs = [PasscodeInputModuleInput]()
  
  override init(router: NavigationControllerRouter) {
    super.init(router: router)
    passcodeNavigationController.setNavigationBarHidden(true, animated: false)
  }
  
  override func start() {
    open()
  }
}

private extension PasscodeCreateCoordinator {
  func open() {
    let passcodeModule = PasscodeAssembly.module(
      navigationController: passcodeNavigationController,
      isBiometryTurnedOn: false
    )
    
    passcodeModule.output.didTapBackspace = { [weak self] in
      self?.passcodeInputs.last?.didTapBackspace()
    }
    
    passcodeModule.output.didTapDigit = { [weak self] digit in
      self?.passcodeInputs.last?.didTapDigit(digit)
    }
    
    passcodeModule.output.didTapBiometry = { [weak self] in
      self?.passcodeInputs.last?.didTapBiometry()
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      passcodeModule.view.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      passcodeModule.view.setupBackButton()
    }

    router.push(viewController: passcodeModule.view,
                animated: true)
    openCreatePasscode()
  }
  
  func openCreatePasscode() {
    let passcodeInput = PasscodeInputAssembly.module(
      title: TKLocales.Passcode.create
    )
    
    passcodeInput.output.didFinishInput = { passcode in
      return .none
    }
    
    passcodeInput.output.didEnterPasscode = { [weak self] passcode in
      self?.openReenterPasscode(enteredPasscode: passcode)
    }
    
    passcodeInputs.append(passcodeInput.input)
    
    passcodeNavigationController.pushViewController(
      passcodeInput.viewController,
      animated: true
    )
  }
  
  func openReenterPasscode(enteredPasscode: String) {
    let passcodeInput = PasscodeInputAssembly.module(
      title: TKLocales.Passcode.reenter
    )
    
    passcodeInput.output.didFinishInput = { passcode in
      return passcode == enteredPasscode ? .success : .failed
    }
    
    passcodeInput.output.didEnterPasscode = { [weak self] passcode in
      self?.didCreatePasscode?(passcode)
    }
    
    passcodeInput.output.didFailed = { [weak self] in
      self?.passcodeNavigationController.popViewController(animated: true)
      _ = self?.passcodeInputs.popLast()
    }
    
    passcodeInputs.append(passcodeInput.input)
    
    passcodeNavigationController.pushViewController(
      passcodeInput.viewController,
      animated: true
    )
  }
}

extension PasscodeCreateCoordinator {
  static func present(parentCoordinator: Coordinator,
                      parentRouter: NavigationControllerRouter,
                      repositoriesAssembly: KeeperCore.RepositoriesAssembly,
                      onCancel: @escaping () -> Void,
                      onCreate: @escaping (String) -> Void) {
    let coordinator = PasscodeCreateCoordinator(router: parentRouter)
    
    coordinator.didCancel = { [weak coordinator, weak parentCoordinator] in
      parentRouter.dismiss(animated: true) {
        parentCoordinator?.removeChild(coordinator)
        onCancel()
      }
    }
    
    coordinator.didCreatePasscode = { passcode in
      onCreate(passcode)
    }

    parentCoordinator.addChild(coordinator)
    coordinator.start()
  }
}

