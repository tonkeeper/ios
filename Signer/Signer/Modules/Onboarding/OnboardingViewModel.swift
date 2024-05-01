import Foundation
import TKUIKit

protocol OnboardingViewModel: AnyObject {
  var didUpdateTitleDescription: ((TKTitleDescriptionHeaderView.Model) -> Void)? { get set }
  var didUpdateCreateButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)? { get set }
  var didUpdateImportButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

protocol OnboardingModuleOutput: AnyObject {
  var didTapCreateButton: (() -> Void)? { get set }
  var didTapImportButton: (() -> Void)? { get set }
}

final class OnboardingViewModelImplementation: OnboardingViewModel, OnboardingModuleOutput {
  var didUpdateTitleDescription: ((TKTitleDescriptionHeaderView.Model) -> Void)?
  var didUpdateCreateButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)?
  var didUpdateImportButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)?
  
  var didTapCreateButton: (() -> Void)?
  var didTapImportButton: (() -> Void)?
  
  func viewDidLoad() {
    let titleDescriptionModel: TKTitleDescriptionHeaderView.Model = .init(
      title: "Tonsign",
      bottomDescription: "The storage place for your keys to sign transactions in Tonkeeper."
    )
    didUpdateTitleDescription?(titleDescriptionModel)
    
    let createButtonModel = TKButtonControl<ButtonTitleContentView>.Model(contentModel: .init(title: "Create New Wallet")) { [weak self] in
      self?.didTapCreateButton?()
    }
    didUpdateCreateButton?(createButtonModel)
    
    let importButtonModel = TKButtonControl<ButtonTitleContentView>.Model(contentModel: .init(title: "Import Existing Wallet")) { [weak self] in
      self?.didTapImportButton?()
    }
    didUpdateImportButton?(importButtonModel)
  }
}
