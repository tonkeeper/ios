import UIKit
import TKUIKit
import TKScreenKit

protocol InputRecoveryPhraseViewModel: AnyObject {
  var didUpdateModel: ((TKInputRecoveryPhraseView.Model) -> Void)? { get set }
  var didUpdateContinueButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)? { get set }
  var didUpdateWordValidationState: ((_ index: Int, _ isValid: Bool) -> Void)? { get set }
  var didUpdateWord: ((_ word: String, _ index: Int) -> Void)? { get set }
  var didSelectInput: ((_ index: Int) -> Void)? { get set }
  var didDeselectInput: (() -> Void)? { get set }
  
  func viewDidLoad()
  func didTapContinueButton()
  func didInputWord(_ word: String, atIndex index: Int)
  func didDeactivateField(atIndex index: Int)
  func shouldPaste(pasteString: String, atIndex index: Int) -> Bool
}

protocol InputRecoveryPhraseModuleOutput: AnyObject {
  var didEnterRecoveryPhrase: (([String]) -> Void)? { get set }
}

final class InputRecoveryPhraseViewModelImplementation: InputRecoveryPhraseViewModel, InputRecoveryPhraseModuleOutput {
  var didUpdateModel: ((TKInputRecoveryPhraseView.Model) -> Void)?
  var didUpdateContinueButton: ((TKButtonControl<ButtonTitleContentView>.Model) -> Void)?
  var didUpdateWordValidationState: ((_ index: Int, _ isValid: Bool) -> Void)?
  var didUpdateWord: ((_ word: String, _ index: Int) -> Void)?
  var didSelectInput: ((_ index: Int) -> Void)?
  var didDeselectInput: (() -> Void)?
  
  var didEnterRecoveryPhrase: (([String]) -> Void)?
  
  private var words = Array(repeating: "", count: .wordsCount)
  
  func viewDidLoad() {
    let titleDescriptionModel = TKTitleDescriptionHeaderView.Model(
      title: "Enter Recovery Phrase",
      bottomDescription: "When you created this wallet, you got a 24-word recovery phrase. Enter it to restore access to your wallet."
    )
    
    let wordInputModels: [TKInputRecoveryPhraseView.Model.WordInputModel] = (0..<Int.wordsCount).map { index in
        .init(index: index + 1)
    }
    
    let model = TKInputRecoveryPhraseView.Model(
      titleDescriptionModel: titleDescriptionModel,
      wordInputModels: wordInputModels
    )
    didUpdateModel?(model)
    
    let continueButtonModel = TKButtonControl<ButtonTitleContentView>.Model(
      contentModel: .init(title: "Continue")
    ) { [weak self] in
      guard let self = self else { return }
      self.didTapContinueButton()
    }
    didUpdateContinueButton?(continueButtonModel)
  }
  
  func didTapContinueButton() {
    let invalidWordsIndexes = getInvalidWordsIndexes()
    guard invalidWordsIndexes.isEmpty else {
      highlightInvalidWords(with: invalidWordsIndexes)
      return
    }
    didEnterRecoveryPhrase?(words)
  }
  
  func didInputWord(_ word: String, atIndex index: Int) {
    didUpdateWordValidationState?(index, true)
    words[index] = word
  }
  
  func didDeactivateField(atIndex index: Int) {
    let word = words[index]
    let isValid = isWordValid(word) || word.isEmpty
    didUpdateWordValidationState?(index, isValid)
  }
  
  func shouldPaste(pasteString: String, atIndex index: Int) -> Bool {
    let pastedWords = pasteString
      .components(separatedBy: CharacterSet([" ", ",", "\n"]))
      .filter { !$0.isEmpty }
  
    var lastPastedWordIndex = 0
    for (wordIndex, word) in pastedWords.enumerated() {
      guard index + wordIndex < .wordsCount else {
        break
      }
      words[index + wordIndex] = word
      didUpdateWord?(word, index + wordIndex)
      lastPastedWordIndex = index + wordIndex
    }
    
    let invalidWordsIndexes = getInvalidWordsIndexes()
    if !invalidWordsIndexes.isEmpty {
      highlightInvalidWords(with: invalidWordsIndexes)
    }

    didSelectInput?(lastPastedWordIndex)
    
    return false
  }
}

private extension InputRecoveryPhraseViewModelImplementation {
  func isWordValid(_ word: String) -> Bool {
    true
  }
  
  func getInvalidWordsIndexes() -> [Int] {
    words
      .enumerated()
      .filter { !isWordValid($0.element) }
      .map { $0.offset }
  }
  
  func highlightInvalidWords(with indexes: [Int]) {
    indexes.forEach { didUpdateWordValidationState?($0, false) }
  }
}

private extension Int {
  static let wordsCount = 24
}
