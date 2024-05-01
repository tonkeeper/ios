import UIKit
import SignerCore

final class CreateKeyCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  var didCreateKey: (() -> Void)?
  
  private let assembly: SignerCore.Assembly
  
  init(router: NavigationControllerRouter,
       assembly: SignerCore.Assembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openNameYourKey()
  }
}

private extension CreateKeyCoordinator {
  func openNameYourKey() {
    let module = EditWalletNameModuleAssembly.module(
      configurator: CreateEditWalletNameViewModelConfigurator(),
      defaultName: nil
    )
    module.view.setCloseButton { [weak self] in
      self?.didFinish?()
    }
    module.output.didEnterWalletName = { [weak self] walletName in
      self?.createKey(name: walletName)
    }
    router.push(viewController: module.view)
  }
  
  func createKey(name: String) {
    let keysAddController = assembly.keysAddController()
    do {
      try keysAddController.createWalletKey(name: name)
      didCreateKey?()
    } catch {
      print("Log: Key creation failed, error \(error)")
    }
  }
}
