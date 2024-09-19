import Foundation
import TKUIKit
import TKLocalize
import TKCore

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
      title: InfoProvider.appName(),
      bottomDescription: TKLocales.Onboarding.caption
    )
    
    var createButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    createButtonConfiguration.content.title = .plainString(TKLocales.Onboarding.Buttons.createNew)
    createButtonConfiguration.action = { [weak self] in
      self?.didTapCreateButton?()
    }
    
    var importButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    importButtonConfiguration.content.title = .plainString(TKLocales.Onboarding.Buttons.importExisting)
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
