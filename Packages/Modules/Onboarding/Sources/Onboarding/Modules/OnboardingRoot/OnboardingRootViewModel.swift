import Foundation
import TKUIKit

protocol OnboardingRootModuleOutput: AnyObject {
  var didTapCreateButton: (() -> Void)? { get set }
  var didTapImportButton: (() -> Void)? { get set }
}

protocol OnboardingRootViewModel: AnyObject {
  var didUpdateModel: ((OnboardingRootView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class OnboardingRootViewModelImplementation: OnboardingRootViewModel, OnboardingRootModuleOutput {
  
  // MARK: - OnboardingRootModuleOutput
  
  var didTapCreateButton: (() -> Void)?
  var didTapImportButton: (() -> Void)?
  
  // MARK: - OnboardingRootViewModel
  
  var didUpdateModel: ((OnboardingRootView.Model) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
  }
}

private extension OnboardingRootViewModelImplementation {
  func createModel() -> OnboardingRootView.Model {
    
    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: "Tonkeeper",
      bottomDescription: "Create a new wallet or add an existing one"
    )
    
    let createButtonModel = TKUIActionButton.Model(
      title: "Create New Wallet"
    )
    
    let importButtonModel = TKUIActionButton.Model(
      title: "Import Existing Wallet"
    )
    
    return OnboardingRootView.Model(
      titleDescriptionModel: titleDescriptionModel,
      createButtonModel: createButtonModel,
      importButtonModel: importButtonModel
    )
  }
}
