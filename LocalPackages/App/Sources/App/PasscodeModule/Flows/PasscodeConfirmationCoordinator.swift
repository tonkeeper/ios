import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore

public final class PasscodeConfirmationCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didConfirm: (() -> Void)?
  
  private let passcodeConfirmationController: PasscodeConfirmationController
  
  public init(router: NavigationControllerRouter,
              passcodeConfirmationController: PasscodeConfirmationController) {
    self.passcodeConfirmationController = passcodeConfirmationController
    super.init(router: router)
    router.rootViewController.modalPresentationStyle = .fullScreen
    router.rootViewController.modalTransitionStyle = .crossDissolve
  }
  
  public override func start() {
    openInputPasscode()
  }
}

private extension PasscodeConfirmationCoordinator {
  func openInputPasscode() {
    var biometryProvider = PasscodeConfirmationBiometryProvider(biometryAuthentificator: BiometryAuthentificator())
    
    biometryProvider.didSuccessBiometry = { [weak self] in
      self?.didConfirm?()
    }
    
    let passcodeInput = PasscodeInputAssembly.module(
      title: "Enter passcode",
      validator: PasscodeConfirmationInputValidator(
        passcodeConfirmationController: passcodeConfirmationController
      ),
      biometryProvider: biometryProvider
    )
    
    passcodeInput.output.didInputPasscode = { [weak self] _ in
      self?.didConfirm?()
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
}

private struct PasscodeConfirmationInputValidator: PasscodeInputValidator {
  private let passcodeConfirmationController: PasscodeConfirmationController
  
  init(passcodeConfirmationController: PasscodeConfirmationController) {
    self.passcodeConfirmationController = passcodeConfirmationController
  }
  
  func validatePasscodeInput(_ input: String) -> PasscodeInputValidatorResult {
    passcodeConfirmationController.validatePasscodeInput(input) ? .success : .failed
  }
}

private struct PasscodeConfirmationBiometryProvider: PasscodeInputBiometryProvider {
  
  private let biometryAuthentificator: BiometryAuthentificator
  
  init(biometryAuthentificator: BiometryAuthentificator) {
    self.biometryAuthentificator = biometryAuthentificator
  }
  
  var didSuccessBiometry: (() -> Void)?
  var didFailedBiometry: (() -> Void)?
  
  func checkBiometryStatus() -> PasscodeInputBiometryProviderState {
    switch biometryAuthentificator.biometryType {
    case .faceID:
      return .faceId
    case .touchID:
      return .touchId
    case .none, .unknown:
      return .none
    }
  }
  
  func evaluateBiometry() {
    Task {
      let result = await biometryAuthentificator.evaluate(policy: .deviceOwnerAuthenticationWithBiometrics)
      switch result {
      case .failure:
        await MainActor.run {
          didFailedBiometry?()
        }
      case .success(let isSuccess):
        await MainActor.run {
          isSuccess ? didSuccessBiometry?() : didFailedBiometry?()
        }
      }
    }
  }
}
