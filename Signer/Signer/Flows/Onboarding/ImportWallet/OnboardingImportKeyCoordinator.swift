import UIKit
import TKScreenKit
import TKCoordinator
import SignerCore
import SignerLocalize

final class OnboardingImportKeyCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
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

private extension OnboardingImportKeyCoordinator {
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
    module.viewController.setupBackButton()
    module.output.didInputRecoveryPhrase = { [weak self] recoveryPhrase, completion in
      completion()
      self?.openCreatePassword(phrase: recoveryPhrase)
    }
    router.push(viewController: module.viewController,
                onPopClosures: { [weak self] in
      self?.didFinish?()
    })
  }
  
  func openCreatePassword(phrase: [String]) {
    let coordinator = CreatePasswordCoordinator(
      router: router,
      showKeyboardOnAppear: true,
      showAsRoot: false,
      isChangePassword: false
    )
    coordinator.didFinish = { [weak self, unowned coordinator] in
      self?.removeChild(coordinator)
    }

    coordinator.didCreatePassword = { [weak self] password in
      self?.openNameYourKey(phrase: phrase, password: password)
    }

    addChild(coordinator)
    coordinator.start()
  }

  func openNameYourKey(phrase: [String], password: String) {
    let module = EditWalletNameModuleAssembly.module(
      configurator: CreateEditWalletNameViewModelConfigurator(),
      defaultName: nil
    )
    module.view.presentationMode = .fullscreen
    module.view.setupBackButton()
    module.output.didEnterWalletName = { [weak self] walletName in
      self?.createKey(phrase: phrase, password: password, name: walletName)
    }
    router.push(viewController: module.view)
  }
  
  func createKey(phrase: [String], password: String, name: String) {
    let keysAddController = assembly.keysAddController()
    Task {
      do {
        try await keysAddController.importWalletKey(
          phrase: phrase,
          name: name,
          password: password
        )
        await MainActor.run {
          didImportKey?()
        }
      } catch {
        await MainActor.run {
          print("Log: Key import failed, error \(error)")
        }
      }
    }
  }
}
