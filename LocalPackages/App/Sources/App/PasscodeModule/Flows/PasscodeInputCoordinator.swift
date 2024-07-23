import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKLocalize

protocol PasscodeInputValidator {
  func validate(passcode: String) async -> PasscodeInputValidationResult
}

protocol PasscodeInputBiometryProvider {
  func getBiometryState() async -> TKKeyboardView.Biometry
}

final class PasscodeInputCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didInputPasscode: ((String) -> Void)?
  var didCancel: (() -> Void)?
  
  private let validator: PasscodeInputValidator
  private let biometryProvider: PasscodeInputBiometryProvider
  private let mnemonicsRepository: MnemonicsRepository
  private let securityStore: SecurityStoreV2
    
  init(router: NavigationControllerRouter,
       validator: PasscodeInputValidator,
       biometryProvider: PasscodeInputBiometryProvider,
       mnemonicsRepository: MnemonicsRepository,
       securityStore: SecurityStoreV2) {
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
    
    passcodeInputModule.output.validateInput = { [weak self] input in
      guard let self else { return .failed }
      let result = await Task {
        await self.validator.validate(passcode: input)
      }.value
      return result
    }
    
    passcodeInputModule.output.didFinish = { [weak self] passcode in
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
        do {
          let passcode = try self.mnemonicsRepository.getPassword()
          await MainActor.run {
            passcodeInputModule.input.didSetInput(passcode)
          }
        } catch {
          print("dsd")
        }
      }
    }
    
    passcodeModule.output.biometryProvider = { [weak self] in
      await self?.biometryProvider.getBiometryState() ?? .none
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
                                      mnemonicsRepository: MnemonicsRepository,
                                      securityStore: SecurityStoreV2) -> PasscodeInputCoordinator {
    let validator = PasscodeConfirmationValidator(
      mnemonicsRepository: mnemonicsRepository
    )
    return PasscodeInputCoordinator(
      router: router,
      validator: validator,
      biometryProvider: PasscodeBiometryProvider(
        biometryProvider: BiometryProvider(),
        securityStore: securityStore
      ),
      mnemonicsRepository: mnemonicsRepository,
      securityStore: securityStore
    )
  }
}

extension PasscodeInputCoordinator {
  static func present<ParentRouterViewController: UIViewController>(parentCoordinator: Coordinator,
                                                                    parentRouter: ContainerViewControllerRouter<ParentRouterViewController>,
                                                                    mnemonicsRepository: MnemonicsRepository,
                                                                    securityStore: SecurityStoreV2,
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
                                                                        securityStore: SecurityStoreV2) async -> String? {
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
