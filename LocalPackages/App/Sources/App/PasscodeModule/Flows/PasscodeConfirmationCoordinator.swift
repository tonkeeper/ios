import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore

public final class PasscodeConfirmationCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didConfirm: (() -> Void)?
  
  private let passcodeConfirmationController: PasscodeConfirmationController
  
  public init(router: NavigationControllerRouter, passcodeConfirmationController: PasscodeConfirmationController) {
    self.passcodeConfirmationController = passcodeConfirmationController
    super.init(router: router)
    router.rootViewController.modalPresentationStyle = .fullScreen
    router.rootViewController.modalTransitionStyle = .crossDissolve
  }
  
  public override func start() {
    openCreatePasscode()
  }
}

private extension PasscodeConfirmationCoordinator {
  func openCreatePasscode() {
    let navigationController = TKNavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    navigationController.interactivePopGestureEnabled = false
    
    let module = PasscodeAssembly.module(
      navigationController: navigationController,
      biometryProvider: PasscodeConfirmationBiometryProvider(
        biometryAuthentificator: BiometryAuthentificator(),
        isBiometryEnabled: passcodeConfirmationController.isBiometryEnabled
      )
    )
    
    let coordinator = PasscodeConfirmationChildCoordinator(
      router: NavigationControllerRouter(
        rootViewController: navigationController),
      passcodeConfirmationController: passcodeConfirmationController,
      passcodeOutput: module.output
    )
    
    coordinator.didCancel = { [weak self] in
      self?.didCancel?()
    }
    
    coordinator.didConfirm = { [weak self] in
      self?.didConfirm?()
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

public final class PasscodeConfirmationChildCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didConfirm: (() -> Void)?
  
  private let passcodeConfirmationController: PasscodeConfirmationController
  private var passcodeInputModule: PasscodeInputModuleInput?
  private weak var passcodeOutput: PasscodeModuleOutput?
  
  public init(router: NavigationControllerRouter, passcodeConfirmationController: PasscodeConfirmationController, passcodeOutput: PasscodeModuleOutput) {
    self.passcodeConfirmationController = passcodeConfirmationController
    self.passcodeOutput = passcodeOutput
    super.init(router: router)
    
    passcodeOutput.didTapDigit = { [weak self] digit in
      self?.passcodeInputModule?.didTapDigit(digit)
    }
    
    passcodeOutput.didTapBackspace = { [weak self] in
      self?.passcodeInputModule?.didTapBackspace()
    }
    
    passcodeOutput.didTapBiometry = { [weak self] in
      self?.passcodeInputModule?.didTapBiometry()
    }
  }
  
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

private extension PasscodeConfirmationChildCoordinator {
  func openInputPasscode() {
    var biometryProvider = PasscodeConfirmationBiometryProvider(
      biometryAuthentificator: BiometryAuthentificator(),
      isBiometryEnabled: passcodeConfirmationController.isBiometryEnabled
    )
    
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
    
    passcodeInputModule = passcodeInput.input
        
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
  private let isBiometryEnabled: Bool
  
  init(biometryAuthentificator: BiometryAuthentificator,
       isBiometryEnabled: Bool) {
    self.biometryAuthentificator = biometryAuthentificator
    self.isBiometryEnabled = isBiometryEnabled
  }
  
  var didSuccessBiometry: (() -> Void)?
  var didFailedBiometry: (() -> Void)?
  
  func checkBiometryStatus() -> PasscodeInputBiometryProviderState {
    guard isBiometryEnabled else { return .none }
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
