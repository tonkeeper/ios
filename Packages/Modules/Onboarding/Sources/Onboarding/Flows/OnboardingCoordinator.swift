import UIKit
import TKCoordinator

public final class OnboardingCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
//  var didCompleteOnboarding: (() -> Void)?
  
  public override func start() {
    openOnboardingStart()
  }
}

private extension OnboardingCoordinator {
  func openOnboardingStart() {
    let module = OnboardingRootAssembly.module()
    
    module.output.didTapCreateButton = { [weak self] in
      
    }
    
    module.output.didTapImportButton = { [weak self] in
      
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openCreate() {
//    let createCoordinator = OnboardingCreateKeyCoordinator(router: router)
//    createCoordinator.didFinish = { [weak self, unowned createCoordinator] in
//      self?.removeChild(createCoordinator)
//    }
//    createCoordinator.didCreateKey = { [weak self, unowned createCoordinator] in
//      self?.removeChild(createCoordinator)
//      self?.didCompleteOnboarding?()
//    }
//
//    addChild(createCoordinator)
//    createCoordinator.start()
  }
  
  func openImport() {
//    let importCoordinator = OnboardingImportKeyCoordinator(router: router)
//    importCoordinator.didFinish = { [weak self, unowned importCoordinator] in
//      self?.removeChild(importCoordinator)
//    }
//
//    importCoordinator.didImportKey = { [weak self, unowned importCoordinator] in
//      self?.removeChild(importCoordinator)
//      self?.didCompleteOnboarding?()
//    }
//
//    addChild(importCoordinator)
//    importCoordinator.start()
  }
}
