import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKLocalize

final class PasscodeChangeCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didChangePasscode: (() -> Void)?
  var didCancel: (() -> Void)?
  
  private let passcodeNavigationController = UINavigationController()
  private var passcodeModuleInput: PasscodeModuleInput?
  private var passcodeInputs = [PasscodeInputModuleInput]()
  
  private let keeperCoreAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       keeperCoreAssembly: KeeperCore.MainAssembly) {
    self.keeperCoreAssembly = keeperCoreAssembly
    super.init(router: router)
    passcodeNavigationController.setNavigationBarHidden(true, animated: false)
  }
  
  override func start() {
    open()
  }
}

private extension PasscodeChangeCoordinator {
  func open() {
    let passcodeModule = PasscodeAssembly.module(
      navigationController: passcodeNavigationController
    )
    
    passcodeModuleInput = passcodeModule.input
    
    passcodeModule.output.didTapBackspace = { [weak self] in
      self?.passcodeInputs.last?.didTapBackspace()
    }
    
    passcodeModule.output.didTapDigit = { [weak self] digit in
      self?.passcodeInputs.last?.didTapDigit(digit)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      passcodeModule.view.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      passcodeModule.view.setupBackButton()
    }

    router.push(viewController: passcodeModule.view,
                animated: false)
    openInputPasscode()
  }
  
  func openInputPasscode() {
    let passcodeInput = PasscodeInputAssembly.module(
      title: TKLocales.Passcode.enter
    )
    
    passcodeInput.output.validateInput = { [weak self] input in
      guard let self else { return .failed }
      return await Task<PasscodeInputValidationResult, Never> {
        let isValid = await self.keeperCoreAssembly.repositoriesAssembly.mnemonicsRepository().checkIfPasswordValid(
          input
        )
        return isValid ? .success : .failed
      }.value
    }
    
    passcodeInput.output.didFinish = { [weak self] passcode in
      self?.openCreatePasscode(oldPasscode: passcode)
    }
    
    passcodeInputs.append(passcodeInput.input)
    
    passcodeNavigationController.pushViewController(
      passcodeInput.viewController,
      animated: true
    )
  }
  
  func openCreatePasscode(oldPasscode: String) {
    let passcodeInput = PasscodeInputAssembly.module(
      title: TKLocales.Passcode.create
    )
    
    passcodeInput.output.validateInput = { passcode in
      return .none
    }
    
    passcodeInput.output.didFinish = { [weak self] passcode in
      self?.openReenterPasscode(oldPasscode: oldPasscode, newPasscode: passcode)
    }
    
    passcodeInputs.append(passcodeInput.input)
    
    passcodeNavigationController.pushViewController(
      passcodeInput.viewController,
      animated: true
    )
  }
  
  func openReenterPasscode(oldPasscode: String, newPasscode: String) {
    let passcodeInput = PasscodeInputAssembly.module(
      title: TKLocales.Passcode.reenter
    )
    
    passcodeInput.output.validateInput = { passcode in
      return passcode == newPasscode ? .success : .failed
    }
    
    passcodeInput.output.didFinish = { [weak self] passcode in
      guard let self else { return }
      Task {
        try await self.keeperCoreAssembly.repositoriesAssembly.mnemonicsRepository().changePassword(
          oldPassword: oldPasscode,
          newPassword: newPasscode
        )
        try? self.keeperCoreAssembly.repositoriesAssembly.mnemonicsRepository().deletePassword()
        await self.keeperCoreAssembly.storesAssembly.securityStoreV2.setIsBiometryEnable(false)
        await MainActor.run {
          self.didChangePasscode?()
        }
      }
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
