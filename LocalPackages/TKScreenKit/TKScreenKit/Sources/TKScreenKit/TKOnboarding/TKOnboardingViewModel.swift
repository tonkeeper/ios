import UIKit
import TKUIKit
import TKLocalize

public protocol TKOnboardingModuleOutput: AnyObject {
  var didTapPrimaryButton: (() -> Void)? { get set }
  var didTapSecondaryButton: (() -> Void)? { get set }
}

protocol TKOnboardingViewModel: AnyObject {
  var didUpdateModel: ((TKOnboardingView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

public struct TKOnboardingModel {
  public let title: String
  public let subtitle: String
  public let coverImage: UIImage?
  public let primaryButtonTitle: String
  public let secondaryButtonTitle: String
  
  public init(title: String, 
              subtitle: String,
              coverImage: UIImage?,
              primaryButtonTitle: String,
              secondaryButtonTitle: String) {
    self.title = title
    self.subtitle = subtitle
    self.coverImage = coverImage
    self.primaryButtonTitle = primaryButtonTitle
    self.secondaryButtonTitle = secondaryButtonTitle
  }
}

final class TKOnboardingViewModelImplementation: TKOnboardingViewModel, TKOnboardingModuleOutput {
  
  // MARK: - OnboardingRootModuleOutput
  
  var didTapPrimaryButton: (() -> Void)?
  var didTapSecondaryButton: (() -> Void)?
  
  // MARK: - OnboardingRootViewModel
  
  var didUpdateModel: ((TKOnboardingView.Model) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
  }
  
  // MARK: - Dependencies
  
  private let model: TKOnboardingModel
  
  // MARK: - Init
  
  init(model: TKOnboardingModel) {
    self.model = model
  }
}

private extension TKOnboardingViewModelImplementation {
  func createModel() -> TKOnboardingView.Model {

    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: model.title,
      bottomDescription: model.subtitle
    )
    
    var primaryButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    primaryButtonConfiguration.content.title = .plainString(model.primaryButtonTitle)
    primaryButtonConfiguration.action = { [weak self] in
      self?.didTapPrimaryButton?()
    }
    
    var secondaryButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    secondaryButtonConfiguration.content.title = .plainString(model.secondaryButtonTitle)
    secondaryButtonConfiguration.action = { [weak self] in
      self?.didTapSecondaryButton?()
    }
      
    return TKOnboardingView.Model(
      coverImage: model.coverImage,
      titleDescriptionModel: titleDescriptionModel,
      primaryButtonConfiguration: primaryButtonConfiguration,
      secondaryButtonConfiguration: secondaryButtonConfiguration
    )
  }
}
