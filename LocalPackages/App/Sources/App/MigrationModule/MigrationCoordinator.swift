import UIKit
import TKUIKit
import TKLocalize
import TKCoordinator
import TKCore
import KeeperCore

final class MigrationCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  var didLogout: (() -> Void)?
  
  private let migrationController: MigrationController
  private let rnService: RNService
  private let biometryProvider: PasscodeInputBiometryProvider
  
  init(migrationController: MigrationController,
       rnService: RNService,
       router: NavigationControllerRouter) {
    self.migrationController = migrationController
    self.rnService = rnService
    self.biometryProvider = MigrationPasscodeBiometryProvider(
      biometryProvider: BiometryProvider(),
      rnService: rnService
    )
    super.init(router: router)
  }
  
  override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
    performMigration()
  }
  
  private func performMigration() {
    Task {
      try await migrationController.migrate { validation in
        return await withCheckedContinuation { continuation in
          DispatchQueue.main.async {
            self.openPasscode(validation: validation) { passcode in
              continuation.resume(returning: passcode)
            }
          }
        }
      }
      await MainActor.run {
        didFinish?()
      }
    }
  }
  
  private func openPasscode(validation: @escaping (String) async -> Bool, finish: @escaping (String) -> Void) {
    
    let navigationController = TKNavigationController()
    navigationController.setNavigationBarHidden(true, animated: false)
    
    let passcodeInputModule = PasscodeInputAssembly.module(
      title: TKLocales.Passcode.enter
    )
    
    let passcodeModule = PasscodeAssembly.module(
      navigationController: navigationController
    )
    
    passcodeInputModule.output.validateInput = { input in
      return await Task {
        return await validation(input) ? .success : .failed
      }.value
    }
    
    passcodeInputModule.output.didFinish = { passcode in
      finish(passcode)
    }
    
    passcodeModule.output.didTapBackspace = {
      passcodeInputModule.input.didTapBackspace()
    }
    
    passcodeModule.output.didTapDigit = { digit in
      passcodeInputModule.input.didTapDigit(digit)
    }
    
    passcodeModule.output.biometryProvider = { [biometryProvider] in
      await biometryProvider.getBiometryState()
    }
    
    passcodeModule.output.didTapBiometry = { [weak self] in
      guard let self else { return }
      Task {
        let passcode = try await self.rnService.getBiometryPasscode()
        await MainActor.run {
          passcodeInputModule.input.didSetInput(passcode)
        }
      }
    }
    
    let singOutButton = TKButton(configuration: .titleHeaderButtonConfiguration(category: .secondary))
    singOutButton.configuration.padding.top = 4
    singOutButton.configuration.padding.bottom = 4
    singOutButton.configuration.content = TKButton.Configuration.Content(
      title: .plainString(
        TKLocales.Actions.sign_out
      )
    )
    singOutButton.configuration.action = { [weak self] in
      guard let self else { return }
      self.openSignOutAlert(fromViewController: self.router.rootViewController, didLogout: { [weak self] in
        self?.didLogout?()
        self?.router.dismiss()
      })
    }
    
    passcodeModule.view.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: singOutButton)
    
    navigationController.pushViewController(passcodeInputModule.viewController, animated: false)
    
    router.push(viewController: passcodeModule.view, animated: false)
  }
  
  func openSignOutAlert(fromViewController: UIViewController, didLogout: @escaping () -> Void) {
    let alertViewController = UIAlertController(
      title: TKLocales.SignOutFull.title,
      message: TKLocales.SignOutFull.description,
      preferredStyle: .alert
    )
    alertViewController.addAction(
      UIAlertAction(title: TKLocales.Actions.cancel,
                    style: .default)
    )
    alertViewController.addAction(
      UIAlertAction(title: TKLocales.Actions.sign_out,
                    style: .destructive,
                    handler: { _ in
                      didLogout()
                    })
    )
    fromViewController.present(alertViewController, animated: true)
  }
}

private struct MigrationPasscodeBiometryProvider: PasscodeInputBiometryProvider {
  
  private let biometryProvider: BiometryProvider
  private let rnService: RNService
  
  init(biometryProvider: BiometryProvider,
       rnService: RNService) {
    self.biometryProvider = biometryProvider
    self.rnService = rnService
  }
  
  func getBiometryState() async -> TKUIKit.TKKeyboardView.Biometry {
    guard await rnService.isBiometryEnable() else {
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

