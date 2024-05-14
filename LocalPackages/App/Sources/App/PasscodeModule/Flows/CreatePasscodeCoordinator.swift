import UIKit
import TKCoordinator
import TKUIKit
import TKLocalize

public final class CreatePasscodeCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didCreatePasscode: ((String) -> Void)?
  
  public override func start() {
    openCreatePasscode()
  }
}

private extension CreatePasscodeCoordinator {
  func openCreatePasscode() {
    let navigationController = TKNavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    
    let module = PasscodeAssembly.module(
      navigationController: navigationController,
      biometryProvider: BiometryProvider()
    )
    
    let coordinator = CreatePasscodeChildCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      passcodeOutput: module.output
    )
    
    coordinator.didCancel = { [weak self] in
      self?.didCancel?()
    }
    
    coordinator.didCreatePasscode = { [weak self] passcode in
      self?.didCreatePasscode?(passcode)
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

public final class CreatePasscodeChildCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didCreatePasscode: ((String) -> Void)?
  
  private weak var passcodeOutput: PasscodeModuleOutput?
  
  private var passcodeInputModuleInputs = [PasscodeInputModuleInput]()

  public init(router: NavigationControllerRouter, passcodeOutput: PasscodeModuleOutput) {
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
      _ = self?.passcodeInputModuleInputs.popLast()
    }
  }
  
  public override func start() {
    openCreatePasscode()
  }
}

private extension CreatePasscodeChildCoordinator {
  func openCreatePasscode() {
    let passcodeInput = PasscodeInputAssembly.module(
      title: TKLocales.Passcode.create,
      validator: CreatePasscodeInputValidator(),
      biometryProvider: BiometryProvider()
    )
    
    passcodeInputModuleInputs.append(passcodeInput.input)
    
    passcodeInput.output.didInputPasscode = { [weak self] passcode in
      self?.openReenterPasscode(createdPasscode: passcode)
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

  func openReenterPasscode(createdPasscode: String) {
    let passcodeInput = PasscodeInputAssembly.module(
      title: TKLocales.Passcode.reenter,
      validator: ReenterPasscodeInputValidator(createdPasscode: createdPasscode),
      biometryProvider: BiometryProvider()
    )
    
    passcodeInputModuleInputs.append(passcodeInput.input)
    
    passcodeInput.output.didInputPasscode = { [weak self] passcode in
      self?.didCreatePasscode?(passcode)
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
