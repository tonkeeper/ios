import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore

public final class ChangePasscodeCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didChangePasscode: ((String) -> Void)?
  
  private let passcodeConfirmationController: PasscodeConfirmationController
  
  public init(router: NavigationControllerRouter,
              passcodeConfirmationController: PasscodeConfirmationController) {
    self.passcodeConfirmationController = passcodeConfirmationController
    super.init(router: router)
  }
  
  public override func start() {
    openChangePasscode()
  }
}

private extension ChangePasscodeCoordinator {
  func openChangePasscode() {
    let navigationController = TKNavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    navigationController.interactivePopGestureEnabled = false
    
    let module = PasscodeAssembly.module(
      navigationController: navigationController,
      biometryProvider: BiometryProvider()
    )
    
    let coordinator = ChangePasscodeChildCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      passcodeConfirmationController: passcodeConfirmationController,
      passcodeOutput: module.output
    )
    
    coordinator.didCancel = { [weak self] in
      self?.didCancel?()
    }
    
    coordinator.didChangePasscode = { [weak self] passcode in
      self?.didChangePasscode?(passcode)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.viewController.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.viewController.setupBackButton()
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.push(
      viewController: module.viewController,
      animated: true,
      onPopClosures: { [weak self] in
        self?.didCancel?()
      },
      completion: nil)
  }
}

public final class ChangePasscodeChildCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didChangePasscode: ((String) -> Void)?
  
  private let passcodeConfirmationController: PasscodeConfirmationController
  private weak var passcodeOutput: PasscodeModuleOutput?
  
  private var passcodeInputModuleInputs = [PasscodeInputModuleInput]()

  public init(router: NavigationControllerRouter, 
              passcodeConfirmationController: PasscodeConfirmationController,
              passcodeOutput: PasscodeModuleOutput) {
    self.passcodeConfirmationController = passcodeConfirmationController
    self.passcodeOutput = passcodeOutput
    super.init(router: router)
    
    passcodeOutput.didTapDigit = { [weak self] digit in
      self?.passcodeInputModuleInputs.last?.didTapDigit(digit)
    }
    
    passcodeOutput.didTapBackspace = { [weak self] in
      self?.passcodeInputModuleInputs.last?.didTapBackspace()
    }
    
    passcodeOutput.didTapBiometry = { [weak self] in
      self?.passcodeInputModuleInputs.last?.didTapBiometry()
    }
    
    passcodeOutput.didReset = { [weak self] in
      self?.router.popToRoot()
    }
  }
  
  public override func start() {
    openChangePasscode()
  }
}

private extension ChangePasscodeChildCoordinator {
  func openChangePasscode() {
    let passcodeInput = PasscodeInputAssembly.module(
      title: "Enter current passcode",
      validator: EnterCurrentPasscodeInputValidator(passcodeConfirmationController: passcodeConfirmationController),
      biometryProvider: BiometryProvider()
    )
    
    passcodeInputModuleInputs.append(passcodeInput.input)
    
    passcodeInput.output.didInputPasscode = { [weak self] _ in
      self?.openCreateNewPasscode()
    }
        
    if router.rootViewController.viewControllers.isEmpty {
      passcodeInput.viewController.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      passcodeInput.viewController.setupBackButton()
    }
    
    router.push(
      viewController: passcodeInput.viewController,
      animated: true,
      onPopClosures: { [weak self] in
        self?.didCancel?()
      },
      completion: nil)
  }

  func openCreateNewPasscode() {
    let passcodeInput = PasscodeInputAssembly.module(
      title: "Create new passcode",
      validator: CreatePasscodeInputValidator(),
      biometryProvider: BiometryProvider()
    )
    
    passcodeInputModuleInputs.append(passcodeInput.input)
    
    passcodeInput.output.didInputPasscode = { [weak self] passcode in
      self?.openReenterPasscode(createdPasscode: passcode)
    }
    
    passcodeInput.output.didFailed = { [weak self] in
      self?.router.pop()
    }
    
    passcodeInput.viewController.setupBackButton()
    
    router.push(
      viewController: passcodeInput.viewController,
      animated: true,
      onPopClosures: { [weak self] in
        _ = self?.passcodeInputModuleInputs.popLast()
      },
      completion: nil)
  }
  
  func openReenterPasscode(createdPasscode: String) {
    let passcodeInput = PasscodeInputAssembly.module(
      title: "Re-enter passcode",
      validator: ReenterPasscodeInputValidator(createdPasscode: createdPasscode),
      biometryProvider: BiometryProvider()
    )
    
    passcodeInputModuleInputs.append(passcodeInput.input)
    
    passcodeInput.output.didInputPasscode = { [weak self] passcode in
      self?.didChangePasscode?(passcode)
    }
    
    passcodeInput.output.didFailed = { [weak self] in
      self?.router.pop()
    }
    
    passcodeInput.viewController.setupBackButton()
    
    router.push(
      viewController: passcodeInput.viewController,
      animated: true,
      onPopClosures: { [weak self] in
        _ = self?.passcodeInputModuleInputs.popLast()
      },
      completion: nil)
  }
}

private struct EnterCurrentPasscodeInputValidator: PasscodeInputValidator {
  private let passcodeConfirmationController: PasscodeConfirmationController
  
  init(passcodeConfirmationController: PasscodeConfirmationController) {
    self.passcodeConfirmationController = passcodeConfirmationController
  }
  
  func validatePasscodeInput(_ input: String) -> PasscodeInputValidatorResult {
    passcodeConfirmationController.validatePasscodeInput(input) ? .success : .failed
  }
}

private struct CreatePasscodeInputValidator: PasscodeInputValidator {
  func validatePasscodeInput(_ input: String) -> PasscodeInputValidatorResult {
    .none
  }
}

private struct ReenterPasscodeInputValidator: PasscodeInputValidator {
  let createdPasscode: String
  
  func validatePasscodeInput(_ input: String) -> PasscodeInputValidatorResult {
    input == createdPasscode ? .success : .failed
  }
}

private struct BiometryProvider: PasscodeInputBiometryProvider {
  var didSuccessBiometry: (() -> Void)?
  var didFailedBiometry: (() -> Void)?
  
  func checkBiometryStatus() -> PasscodeInputBiometryProviderState {
    .none
  }
  
  func evaluateBiometry() {}
}
