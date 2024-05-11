import UIKit
import TKScreenKit
import TKCoordinator
import SignerCore
import SignerLocalize

final class OnboardingCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didCompleteOnboarding: (() -> Void)?
  
  private let signerCoreAssembly: SignerCore.Assembly
  
  init(router: NavigationControllerRouter,
       signerCoreAssembly: SignerCore.Assembly) {
    self.signerCoreAssembly = signerCoreAssembly
    super.init(router: router)
  }
  
  override func start() {
    openOnboardingStart()
  }
}

private extension OnboardingCoordinator {
  func openOnboardingStart() {
    let model = TKOnboardingModel(
      title: SignerLocalize.App.name,
      subtitle: SignerLocalize.Onboarding.caption,
      coverImage: .Images.tonsignCover,
      primaryButtonTitle: SignerLocalize.AddKey.Buttons.create_new,
      secondaryButtonTitle: SignerLocalize.AddKey.Buttons.import_existing
    )
    let module = TKOnboardingAssembly.module(model: model)
    
    module.output.didTapPrimaryButton = { [weak self] in
      self?.openCreate()
    }
    
    module.output.didTapSecondaryButton = { [weak self] in
      self?.openImport()
    }
    
    router.push(viewController: module.viewController, animated: false)
  }
  
  func openCreate() {
    let createCoordinator = OnboardingCreateKeyCoordinator(router: router, assembly: signerCoreAssembly)
    createCoordinator.didFinish = { [weak self, unowned createCoordinator] in
      self?.removeChild(createCoordinator)
    }
    createCoordinator.didCreateKey = { [weak self, unowned createCoordinator] in
      self?.removeChild(createCoordinator)
      self?.didCompleteOnboarding?()
    }
    
    addChild(createCoordinator)
    createCoordinator.start()
  }
  
  func openImport() {
    let importCoordinator = OnboardingImportKeyCoordinator(router: router, assembly: signerCoreAssembly)
    importCoordinator.didFinish = { [weak self, unowned importCoordinator] in
      self?.removeChild(importCoordinator)
    }
    
    importCoordinator.didImportKey = { [weak self, unowned importCoordinator] in
      self?.removeChild(importCoordinator)
      self?.didCompleteOnboarding?()
    }
    
    addChild(importCoordinator)
    importCoordinator.start()
  }
}
