import UIKit
import SignerCore

final class ImportKeyCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  var didImportKey: (() -> Void)?
  
  private let assembly: SignerCore.Assembly
  
  init(router: NavigationControllerRouter,
       assembly: SignerCore.Assembly) {
    self.assembly = assembly
    super.init(router: router)
  }
  
  override func start() {
    openEnterRecoveryPhrase()
  }
}

private extension ImportKeyCoordinator {
  func openEnterRecoveryPhrase() {
    let module = InputRecoveryPhraseModuleAssembly.module()
    module.view.setCloseButton { [weak self] in
      self?.didFinish?()
    }
    module.output.didEnterRecoveryPhrase = { [weak self] recoveryPhrase in
      self?.openNameYourKey(phrase: recoveryPhrase)
    }
    router.push(viewController: module.view,
                onPopClosures: { [weak self] in
      self?.didFinish?()
    })
  }

  func openNameYourKey(phrase: [String]) {
    let module = EditWalletNameModuleAssembly.module(
      configurator: CreateEditWalletNameViewModelConfigurator(),
      defaultName: nil
    )
    module.view.setupBackButton()
    module.output.didEnterWalletName = { [weak self] walletName in
      self?.createKey(phrase: phrase, name: walletName)
    }
    router.push(viewController: module.view)
  }
  
  func createKey(phrase: [String], name: String) {
    let keysAddController = assembly.keysAddController()
    do {
      try keysAddController.importWalletKey(phrase: phrase, name: name)
      didImportKey?()
    } catch {
      print("Log: Key creation failed, error \(error)")
    }
  }
}
