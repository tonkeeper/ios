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
  private let biometryProvider: BiometryProvider
  private let mnemonicsRepository: MnemonicsRepository
  private let securityStore: SecurityStore
    
  init(router: NavigationControllerRouter,
       validator: PasscodeValidator,
       biometryProvider: BiometryProvider,
       mnemonicsRepository: MnemonicsRepository,
       securityStore: SecurityStore) {
    self.validator = validator
    self.biometryProvider = biometryProvider
    self.mnemonicsRepository = mnemonicsRepository
    self.securityStore = securityStore
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
      navigationController: navigationController
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
    
    passcodeModule.output.didTapBiometry = { [weak self] in
      guard let self else { return }
      Task {
        let passcode = try self.mnemonicsRepository.getPassword()
        await MainActor.run {
          passcodeInputModule.input.didSetInput(passcode)
        }
      }
    }
    
    passcodeModule.output.biometryProvider = { [weak self] in
      await self?.getBiometry() ?? .none
    }
    
    passcodeModule.view.setupLeftCloseButton { [weak self] in
      self?.didCancel?()
    }
    
    navigationController.pushViewController(passcodeInputModule.viewController, animated: false)
    
    router.push(viewController: passcodeModule.view)
  }
  
  func getBiometry() async -> TKKeyboardView.Biometry {
    guard await securityStore.isBiometryEnabled else {
      return .none
    }
    switch biometryProvider.getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics) {
    case .failure:
      return .none
    case .success(let state):
      switch state {
      case .faceID: return .faceId
      case .touchID: return .touchId
      case .none: return .none
      }
    }
  }
}

extension PasscodeInputCoordinator {
  static func confirmationCoordinator(router: NavigationControllerRouter, 
                                      mnemonicsRepository: MnemonicsRepository,
                                      securityStore: SecurityStore) -> PasscodeInputCoordinator {
    let validator = PasscodeConfirmationValidator(
      mnemonicsRepository: mnemonicsRepository
    )
    return PasscodeInputCoordinator(
      router: router,
      validator: validator,
      biometryProvider: BiometryProvider(),
      mnemonicsRepository: mnemonicsRepository,
      securityStore: securityStore
    )
  }
}

extension PasscodeInputCoordinator {
  static func present<ParentRouterViewController: UIViewController>(parentCoordinator: Coordinator,
                                                                    parentRouter: ContainerViewControllerRouter<ParentRouterViewController>,
                                                                    mnemonicsRepository: MnemonicsRepository,
                                                                    securityStore: SecurityStore,
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
      mnemonicsRepository: mnemonicsRepository,
      securityStore: securityStore
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

extension PasscodeInputCoordinator {
  static func getPasscode<ParentRouterViewController: UIViewController>(parentCoordinator: Coordinator,
                                                                        parentRouter: ContainerViewControllerRouter<ParentRouterViewController>,
                                                                        mnemonicsRepository: MnemonicsRepository,
                                                                        securityStore: SecurityStore) async -> String? {
    return await Task { @MainActor in
      return await withCheckedContinuation { continuation in
        PasscodeInputCoordinator.present(
          parentCoordinator: parentCoordinator,
          parentRouter: parentRouter,
          mnemonicsRepository: mnemonicsRepository,
          securityStore: securityStore,
          onCancel: {
            continuation.resume(returning: nil)
          },
          onInput: {
            continuation.resume(returning: $0)
          }
        )
      }
    }.value
  }
}
