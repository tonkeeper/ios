import UIKit
import TKCoordinator
import SignerCore

final class OnboardingCreateKeyCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  var didCreateKey: (() -> Void)?
  
  private let assembly: SignerCore.Assembly
  
  init(router: NavigationControllerRouter, 
       assembly: SignerCore.Assembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openCreatePassword()
  }
}

private extension OnboardingCreateKeyCoordinator {
  func openCreatePassword() {
    let coordinator = CreatePasswordCoordinator(
      router: router,
      showKeyboardOnAppear: false,
      showAsRoot: false,
      isChangePassword: false
    )
    coordinator.didFinish = { [weak self, unowned coordinator] in
      self?.removeChild(coordinator)
      self?.didFinish?()
    }
    
    coordinator.didCreatePassword = { [weak self] password in
      self?.openNameYourKey(password: password)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openNameYourKey(password: String) {
    let module = EditWalletNameModuleAssembly.module(
      configurator: CreateEditWalletNameViewModelConfigurator(),
      defaultName: nil
    )
    module.view.presentationMode = .fullscreen
    module.view.setupBackButton()
    module.output.didEnterWalletName = { [weak self] walletName in
      self?.createKey(password: password, name: walletName)
    }
    router.push(viewController: module.view)
  }
  
  func createKey(password: String, name: String) {
    let keysAddController = assembly.keysAddController()
    Task {
      do {
        try await keysAddController.createWalletKey(name: name, password: password)
        await MainActor.run {
          didCreateKey?()
        }
      } catch {
        await MainActor.run {
          print("Log: Key creation failed, error \(error)")
        }
      }
    }
  }
}
