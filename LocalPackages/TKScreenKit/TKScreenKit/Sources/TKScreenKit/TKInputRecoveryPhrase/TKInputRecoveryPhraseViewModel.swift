import UIKit
import TKUIKit
import TKLocalize

public protocol TKInputRecoveryPhraseModuleOutput: AnyObject {
  var didInputRecoveryPhrase: (([String], @escaping (() -> Void)) -> Void)? { get set }
}

protocol TKInputRecoveryPhraseViewModel: AnyObject {
  var showToast: ((ToastPresenter.Configuration) -> Void)? { get set }
  var didUpdateModel: ((TKInputRecoveryPhraseView.Model) -> Void)? { get set }
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)? { get set }
  var didUpdatePasteButton: ((TKButton.Configuration) -> Void)? { get set }
  var didUpdatePasteButtonIsHidden: ((Bool) -> Void)? { get set }
  var didUpdateInputValidationState: ((Int, Bool) -> Void)? { get set }
  var didUpdateText: ((Int, String) -> Void)? { get set }
  var didSelectInput: ((Int) -> Void)? { get set }
  var didPaste: ((Int) -> Void)? { get set }
  var didPastePhrase: (() -> Void)? { get set }
  var didUpdateSuggests: ((TKInputRecoveryPhraseSuggestsView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

public enum RecoveryPhraseValidationResult {
  case ton
  case multiaccount
  case invalid
}

public protocol TKInputRecoveryPhraseValidator {
  func validateWord(_ word: String) -> Bool
  func validatePhrase(_ phrase: [String]) -> RecoveryPhraseValidationResult
}

public protocol TKInputRecoveryPhraseSuggestsProvider {
  func suggestsFor(input: String) -> [String]
}

final class TKInputRecoveryPhraseViewModelImplementation: TKInputRecoveryPhraseViewModel, TKInputRecoveryPhraseModuleOutput {
  
  // MARK: - TKInputRecoveryPhraseModuleOutput
  
  var didInputRecoveryPhrase: (([String], @escaping (() -> Void)) -> Void)?
  
  var showToast: ((ToastPresenter.Configuration) -> Void)?
  
  // MARK: - TKInputRecoveryPhraseViewModel
  
  var didUpdateModel: ((TKInputRecoveryPhraseView.Model) -> Void)?
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)?
  var didUpdatePasteButton: ((TKButton.Configuration) -> Void)?
  var didUpdatePasteButtonIsHidden: ((Bool) -> Void)?
  var didUpdateInputValidationState: ((Int, Bool) -> Void)?
  var didUpdateText: ((Int, String) -> Void)?
  var didSelectInput: ((Int) -> Void)?
  var didPaste: ((Int) -> Void)?
  var didPastePhrase: (() -> Void)?
  var didUpdateSuggests: ((TKInputRecoveryPhraseSuggestsView.Model) -> Void)?
  
  func viewDidLoad() {
    continueButtonConfiguration.action = { [weak self] in
      self?.didTapContinueButton()
    }
    didUpdateModel?(createModel())
    
    var pasteButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .tertiary, size: .medium)
    pasteButtonConfiguration.content.title = .plainString(pasteButtonTitle)
    pasteButtonConfiguration.action = { [weak self] in
      guard UIPasteboard.general.hasStrings,
            let string = UIPasteboard.general.string else { return }
      _ = self?.shouldPaste(text: string, index: 0)
    }
    didUpdatePasteButton?(pasteButtonConfiguration)
  }
  
  // MARK: - State
  
  private var phrase = Array(repeating: "", count: .wordsCount)
  private var activeIndex: Int?
  
  private var continueButtonConfiguration: TKButton.Configuration {
    didSet {
      didUpdateContinueButton?(continueButtonConfiguration)
    }
  }
  
  // MARK: - Configuration
  
  private let title: String
  private let caption: String
  private let continueButtonTitle: String
  private let pasteButtonTitle: String
  private let validator: TKInputRecoveryPhraseValidator
  private let suggestsProvider: TKInputRecoveryPhraseSuggestsProvider
  
  // MARK: - Sync queue
  
  private let dispatchQueue = DispatchQueue(label: "TKInputRecoveryPhraseViewModelImplementationQueue")
  
  // MARK: - Init
  
  init(title: String, 
       caption: String,
       continueButtonTitle: String,
       pasteButtonTitle: String,
       validator: TKInputRecoveryPhraseValidator,
       suggestsProvider: TKInputRecoveryPhraseSuggestsProvider) {
    self.title = title
    self.caption = caption
    self.continueButtonTitle = continueButtonTitle
    self.pasteButtonTitle = pasteButtonTitle
    self.validator = validator
    self.suggestsProvider = suggestsProvider
    
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    continueButtonConfiguration.content.title = .plainString(continueButtonTitle)
    self.continueButtonConfiguration = continueButtonConfiguration
  }
}

private extension TKInputRecoveryPhraseViewModelImplementation {
  func createModel() -> TKInputRecoveryPhraseView.Model {
    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: title,
      bottomDescription: caption
    )
    
    let inputs: [TKInputRecoveryPhraseView.Model.InputModel] = (0..<Int.wordsCount)
      .map { index in
        TKInputRecoveryPhraseView.Model.InputModel(
          index: index + 1,
          didUpdateText: { [weak self] text in
            self?.didUpdateText(text, index: index)
          },
          didBeignEditing: { [weak self] in
            self?.didBeginEditing(index: index)
          },
          didEndEditing: { [weak self] in
            self?.didEndEditing(index: index)
          },
          shouldPaste: { [weak self] text in
            self?.shouldPaste(text: text, index: index) ?? false
          },
          didTapReturn: { [weak self] in
            self?.checkForApplyingSuggestion(index: index)
          }
        )
      }
    
    return TKInputRecoveryPhraseView.Model(
      titleDescriptionModel: titleDescriptionModel,
      inputs: inputs
    )
  }
  
  func didUpdateText(_ text: String, index: Int) {
    didUpdateInputValidationState?(index, true)
    phrase[index] = text
    updateSuggests(index: index)
    let isHidden = phrase.map { !$0.isEmpty }.reduce(into: false, { $0 = $0 || $1 })
    didUpdatePasteButtonIsHidden?(isHidden)
  }
  
  func didBeginEditing(index: Int) {
    activeIndex = index
    didSelectInput?(index)
    updateSuggests(index: index)
  }
  
  func didEndEditing(index: Int) {
    activeIndex = nil
    let word = phrase[index]
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      let isValid = self.validator.validateWord(word) || word.isEmpty
      DispatchQueue.main.async {
        self.didUpdateInputValidationState?(index, isValid)
      }
    }
  }
  
  func shouldPaste(text: String, index: Int) -> Bool {
    guard index == 0 else { return false }
    let phrase = text
      .components(separatedBy: CharacterSet([" ", ",", "\n"]))
      .filter { !$0.isEmpty }
      .prefix(.wordsCount)
    phrase.enumerated().forEach { index, word in
      self.phrase[index] = word
    }
    didUpdatePasteButtonIsHidden?(true)
    dispatchQueue.async {
      let wordsValidation = phrase.map {
        self.validator.validateWord($0)
      }
      
      DispatchQueue.main.async {
        phrase.enumerated().forEach { index, word in
          self.didUpdateText?(index, word)
          self.didUpdateInputValidationState?(index, wordsValidation[index])
        }
        if phrase.count == .wordsCount {
          self.didPastePhrase?()
        } else {
          self.didPaste?(phrase.count)
        }
      }
    }
    
    return false
  }

  func checkForApplyingSuggestion(index: Int) {
    dispatchQueue.async {
      guard let input = self.phrase[safe: index] else {
        return
      }

      let suggests = self.suggestsProvider.suggestsFor(input: input)
      guard let suggest = suggests.first else { return }
      DispatchQueue.main.async {
        self.setSuggest(suggest: suggest, index: index)
      }
    }
  }

  func didTapContinueButton() {
    continueButtonConfiguration.showsLoader = true
    dispatchQueue.async { [weak self, phrase] in
      guard let self = self else { return }
      let validationResult = self.validator.validatePhrase(phrase)
      
      switch validationResult {
        case .invalid:
          let wordsValidation = phrase.map {
            self.validator.validateWord($0)
          }
          DispatchQueue.main.async {
            self.continueButtonConfiguration.showsLoader = false
            wordsValidation.enumerated().forEach { index, isValid in
              self.didUpdateInputValidationState?(index, isValid)
            }
          }
        case .multiaccount:
          DispatchQueue.main.async {
            self.continueButtonConfiguration.showsLoader = false
            self.showToast?(ToastPresenter.Configuration(title: TKLocales.Errors.multiaccountError))
          }
        case .ton:
          DispatchQueue.main.async {
            self.didInputRecoveryPhrase?(phrase, {
              self.continueButtonConfiguration.showsLoader = false
            })
          }
      }
    }
  }

  func updateSuggests(index: Int) {
    let input = phrase[index]
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      let suggests = self.suggestsProvider.suggestsFor(input: input)
      let model = TKInputRecoveryPhraseSuggestsView.Model(
        suggests: suggests.map { suggestText in
          TKInputRecoveryPhraseSuggestsButton.Model(text: suggestText) { [weak self] in
            guard let activeIndex = self?.activeIndex else { return }
            self?.setSuggest(suggest: suggestText, index: activeIndex)
        }}
      )
      DispatchQueue.main.async {
        self.didUpdateSuggests?(model)
      }
    }
  }
  
  func setSuggest(suggest: String, index: Int) {
    phrase[index] = suggest
    didUpdateText?(index, suggest)
    if index < .wordsCount - 1 {
      didPaste?(index + 1)
    } else {
      didPastePhrase?()
    }
  }
}

private extension Int {
  static let wordsCount = 24
}
