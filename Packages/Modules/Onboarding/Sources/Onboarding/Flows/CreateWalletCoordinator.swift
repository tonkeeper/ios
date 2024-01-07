import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit

public final class CreateWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didCancel: (() -> Void)?
  var didCreateWallet: (() -> Void)?
  
  public override func start() {
    openCreatePasscode()
  }
}

private extension CreateWalletCoordinator {
  func openCreatePasscode() {
    let passcodeInput = PasscodeInputAssembly.module(
      title: "Create passcode",
      validator: CreatePasscodeInputValidator(),
      biometryProvider: BiometryProvider()
    )
    
    passcodeInput.output.didInputPasscode = { [weak self] passcode in
      self?.openReenterPasscode(createdPasscode: passcode)
    }
    
    passcodeInput.viewController.setupBackButton()
    
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
      self?.didCreateWallet?()
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
  func checkBiometryStatus() -> TKScreenKit.PasscodeInputBiometryProviderState {
    .none
  }
  
  func evaluateBiometry() {}
}
