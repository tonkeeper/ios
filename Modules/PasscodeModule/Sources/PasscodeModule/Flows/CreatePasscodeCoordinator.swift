import UIKit
import TKCoordinator
import TKUIKit

public final class CreatePasscodeCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didCreatePasscode: ((String) -> Void)?
  
  public override func start() {
    openCreatePasscode()
  }
}

private extension CreatePasscodeCoordinator {
  func openCreatePasscode() {
    let passcodeInput = PasscodeInputAssembly.module(
      title: "Create passcode",
      validator: CreatePasscodeInputValidator(),
      biometryProvider: BiometryProvider()
    )
    
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
      title: "Re-enter passcode",
      validator: ReenterPasscodeInputValidator(createdPasscode: createdPasscode),
      biometryProvider: BiometryProvider()
    )
    
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
      onPopClosures: nil,
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
  func checkBiometryStatus() -> PasscodeInputBiometryProviderState {
    .none
  }
  
  func evaluateBiometry() {}
}
