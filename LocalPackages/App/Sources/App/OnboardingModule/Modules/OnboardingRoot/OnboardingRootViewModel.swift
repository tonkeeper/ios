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
    
    var createButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    createButtonConfiguration.content.title = .plainString("Create New Wallet")
    createButtonConfiguration.action = { [weak self] in
      self?.didTapCreateButton?()
    }
    
    var importButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    importButtonConfiguration.content.title = .plainString("Import Existing Wallet")
    importButtonConfiguration.action = { [weak self] in
      self?.didTapImportButton?()
    }
      
    return OnboardingRootView.Model(
      titleDescriptionModel: titleDescriptionModel,
      createButtonConfiguration: createButtonConfiguration,
      importButtonConfiguration: importButtonConfiguration
    )
  }
}
