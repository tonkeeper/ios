import TKUIKit

public protocol TKRecoveryPhraseViewModel: AnyObject {
  var didUpdateModel: ((TKRecoveryPhraseView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

public protocol TKRecoveryPhraseModuleOutput: AnyObject {
  
}

public protocol TKRecoveryPhraseDataProvider {
  var model: TKRecoveryPhraseView.Model { get async }
}

final class TKRecoveryPhraseViewModelImplementation: TKRecoveryPhraseViewModel, TKRecoveryPhraseModuleOutput {
  
  // MARK: - TKRecoveryPhraseModuleOutput
  
  // MARK: - TKRecoveryPhraseViewModel
  
  var didUpdateModel: ((TKRecoveryPhraseView.Model) -> Void)?
  
  func viewDidLoad() {
    Task {
      let model = await provider.model
      await MainActor.run {
        didUpdateModel?(model)
      }
    }
  }
  
  // MARK: - Dependencies
  
  private let provider: TKRecoveryPhraseDataProvider
  
  init(provider: TKRecoveryPhraseDataProvider) {
    self.provider = provider
  }
}
