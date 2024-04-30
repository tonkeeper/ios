import UIKit
import TKUIKit

public protocol TKCheckRecoveryPhraseModuleOutput: AnyObject {
  var didCheckRecoveryPhrase: (() -> Void)? { get set }
}

protocol TKCheckRecoveryPhraseViewModel: AnyObject {
  var didUpdateModel: ((TKCheckRecoveryPhraseView.Model) -> Void)? { get set }
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)? { get set }
  var didUpdateInputValidationState: ((Int, Bool) -> Void)? { get set }
  var didUpdateIsButtonEnabled: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
}

public protocol TKCheckRecoveryPhraseProvider {
  var title: String { get }
  var subtitle: String { get }
  var buttonTitle: String { get }
  var phrase: [String] { get }
}

final class TKCheckRecoveryPhraseViewModelImplementation: TKCheckRecoveryPhraseViewModel, TKCheckRecoveryPhraseModuleOutput {
  
  // MARK: - TKCheckRecoveryPhraseModuleOutput
  
  var didCheckRecoveryPhrase: (() -> Void)?
  
  // MARK: - TKCheckRecoveryPhraseViewModel
  
  var didUpdateModel: ((TKCheckRecoveryPhraseView.Model) -> Void)?
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)?
  var didUpdateInputValidationState: ((Int, Bool) -> Void)?
  var didUpdateIsButtonEnabled: ((Bool) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
    didUpdateIsButtonEnabled?(false)
    continueButtonConfiguration.action = { [weak self] in
      self?.didTapContinueButton()
    }
  }
  
  // MARK: - State
  
  private let indexes = Array(0..<Int.wordsCount)
    .shuffled()
    .prefix(3)
    .sorted()
  
  private var input = [Int: String]()
  private var continueButtonConfiguration: TKButton.Configuration {
    didSet {
      didUpdateContinueButton?(continueButtonConfiguration)
    }
  }

  // MARK: - Configuration
  
  private let provider: TKCheckRecoveryPhraseProvider

  // MARK: - Init
  
  init(provider: TKCheckRecoveryPhraseProvider) {
    self.provider = provider
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary, 
      size: .large
    )
    continueButtonConfiguration.content.title = .plainString("Continue")
    self.continueButtonConfiguration = continueButtonConfiguration
  }
}

private extension TKCheckRecoveryPhraseViewModelImplementation {
  func createModel() -> TKCheckRecoveryPhraseView.Model {
    let bottomDescription = String(
      format: provider.subtitle,
      indexes[0] + 1,
      indexes[1] + 1,
      indexes[2] + 1
    )
    
    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: provider.title,
      bottomDescription: bottomDescription
    )
    
    let inputs: [TKCheckRecoveryPhraseView.Model.InputModel] = indexes
      .enumerated()
      .map { index, wordIndex in
        TKCheckRecoveryPhraseView.Model.InputModel(
          index: wordIndex + 1,
          didUpdateText: { [weak self] text in
            self?.didUpdateText(text, index: wordIndex)
          },
          didBeignEditing: { [weak self] in
            self?.didBeginEditing(index: index)
          },
          didEndEditing: { },
          shouldPaste: { _ in true }
        )
      }

    return TKCheckRecoveryPhraseView.Model(
      titleDescriptionModel: titleDescriptionModel,
      inputs: inputs
    )
  }
  
  func didBeginEditing(index: Int) {
    didUpdateInputValidationState?(index, true)
  }
  
  func didUpdateText(_ text: String, index: Int) {
    input[index] = text
    let isButtonEnabled = input.values.count == .checkWordsCount && input.values.reduce(into: true) { partialResult, input in
      partialResult = partialResult && !input.isEmpty
    }
    didUpdateIsButtonEnabled?(isButtonEnabled)
  }
  
  func didTapContinueButton() {
    let phrase = provider.phrase
    let inputValidationStates: [Bool] = {
      indexes.enumerated().map { index, value in
        phrase[value] == input[value]
      }
    }()
    let isValid = inputValidationStates.allSatisfy { $0 }
    inputValidationStates.enumerated().forEach { index, value in
      didUpdateInputValidationState?(index, value)
    }
    guard isValid else { return }
    didCheckRecoveryPhrase?()
  }
}

private extension Int {
  static let wordsCount = 24
  static let checkWordsCount = 3
}
