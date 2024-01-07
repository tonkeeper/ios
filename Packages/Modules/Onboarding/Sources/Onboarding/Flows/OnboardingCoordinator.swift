import UIKit
import TKCoordinator
import TKUIKit

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
      self?.openCreate()
    }
    
    module.output.didTapImportButton = { [weak self] in
      self?.openImport()
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openCreate() {
    let coordinator = CreateWalletCoordinator(router: router)
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didCreateWallet = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
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
//
//
//class VC: UIViewController {
//  override func viewDidLoad() {
//    super.viewDidLoad()
//    
//    view.backgroundColor = .Background.page
//    
//    let keyboard = TKKeyboardView(configuration: .passcodeConfiguration(biometry: .touchId))
//    
////
////    let button = TKUIPlainKeyboardButton()
////    button.configure(model: .text("5"))
////    
//    view.addSubview(keyboard)
//    keyboard.didTapDigit = {
//      print("didTapDigit")
//      print($0)
//    }
//    keyboard.didTapBackspace = {
//      print("backspace")
//    }
//    keyboard.didTapBiometry = {
//      print("biometry")
//    }
//    keyboard.didTapDecimalSeparator = {
//      
//    }
////
//    keyboard.translatesAutoresizingMaskIntoConstraints = false
//    
//    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//      keyboard.configuration = .passcodeConfiguration(biometry: nil)
//    }
//    
////
//    NSLayoutConstraint.activate([
//      keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//      keyboard.leftAnchor.constraint(equalTo: view.leftAnchor),
//      keyboard.rightAnchor.constraint(equalTo: view.rightAnchor),
////      keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
////      button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
////      button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
//    ])
//  }
//}
