import Foundation
import WalletCoreCore

final class SettingsChangePasscodeCoordinator: Coordinator<NavigationRouter> {
  
  var didClose: (() -> Void)?
  var didChangePasscode: (() -> Void)?
  var didFailedToChangePasscode: (() -> Void)?
  
  private let walletCoreAssembly: WalletCoreAssembly
  
  init(router: NavigationRouter,
       walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    super.init(router: router)
  }
  
  override func start() {
    openEnterPasscode()
  }
}

private extension SettingsChangePasscodeCoordinator {
  func openEnterPasscode() {
    let configurator = PasscodeChangeConfigurator(
      passcodeController: walletCoreAssembly.passcodeController,
      securitySettingsController: walletCoreAssembly.settingsController(),
      biometryAuthentificator: BiometryAuthentificator())
    configurator.didFailed = {}
    configurator.didFinish = { [weak self] _ in
      self?.openCreateNewPasscode()
    }
    
    let module = PasscodeInputAssembly.create(output: nil,
                                              configurator: configurator)
    module.view.setupCloseLeftButton { [weak self] in
      self?.didClose?()
    }
    router.setPresentables([(module.view, nil)])
  }
  
  func openCreateNewPasscode() {
    var configurator = CreatePasscodeConfigurator()
    configurator.didFinish = { [weak self] passcode in
      self?.openReenterNewPasscode(createdPasscode: passcode)
    }
    let module = PasscodeInputAssembly.create(output: nil,
                                              configurator: configurator)
    
    module.view.setupCloseLeftButton { [weak self] in
      self?.didClose?()
    }
    
    router.setPresentables([(module.view, nil)])
  }
  
  func openReenterNewPasscode(createdPasscode: Passcode) {
    var configurator = ReenterPasscodeConfigurator(createdPasscode: createdPasscode)
    configurator.didFinish = { [weak self] passcode in
      guard let self = self else { return }
      do {
        try self.walletCoreAssembly.passcodeController.setPasscode(passcode)
        self.didChangePasscode?()
      } catch {
        self.didFailedToChangePasscode?()
      }
    }
    configurator.didFailed = { [weak self] in
      self?.router.pop()
    }
    let module = PasscodeInputAssembly.create(output: nil,
                                              configurator: configurator)
    module.view.setupBackButton()
    router.push(presentable: module.view)
  }
}
