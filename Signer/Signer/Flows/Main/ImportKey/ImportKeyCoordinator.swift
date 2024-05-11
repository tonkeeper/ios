import UIKit
import TKScreenKit
import TKCoordinator
import SignerCore
import SignerLocalize

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
    let module = TKInputRecoveryPhraseAssembly.module(
      title: SignerLocalize.RecoveryInput.title,
      caption: SignerLocalize.RecoveryInput.caption,
      continueButtonTitle: SignerLocalize.Actions.continue_action,
      pasteButtonTitle: SignerLocalize.Actions.paste,
      validator: InputRecoveryPhraseValidator(),
      suggestsProvider: InputRecoveryPhraseSuggestsProvider(),
      bannerViewProvider: {
        let view = WarningBannerView()
        view.configure(
          model: WarningBannerView.Model(
            text: SignerLocalize.RecoveryInput.Banner.text,
            image: .TKUIKit.Icons.Size28.exclamationmarkTriangle
          )
        )
        return view
      }
    )
    module.viewController.setupLeftCloseButton { [weak self] in
      self?.didFinish?()
    }
    module.output.didInputRecoveryPhrase = { [weak self] recoveryPhrase, completion in
      completion()
      self?.openNameYourKey(phrase: recoveryPhrase)
    }
    router.push(viewController: module.viewController,
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
