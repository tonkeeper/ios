import TKLocalize
import TKUIKit
import UIKit

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
    func caption(numberOne: Int, numberTwo: Int, numberThree: Int) -> String
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
        continueButtonConfiguration.action = { [weak self] in
            self?.didTapContinueButton()
        }
        didUpdateIsButtonEnabled?(false)
    }

    // MARK: - State

    private let indexes: [Int]

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
        continueButtonConfiguration.content.title = .plainString(TKLocales.Actions.continueAction)
        self.continueButtonConfiguration = continueButtonConfiguration

        indexes = Array(0 ..< provider.phrase.count)
            .shuffled()
            .prefix(3)
            .sorted()
    }
}

private extension TKCheckRecoveryPhraseViewModelImplementation {
    func createModel() -> TKCheckRecoveryPhraseView.Model {
        let caption = provider.caption(
            numberOne: indexes[0] + 1,
            numberTwo: indexes[1] + 1,
            numberThree: indexes[2] + 1
        )

        let titleDescriptionModel = TKTitleDescriptionView.Model(
            title: provider.title,
            bottomDescription: caption
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
                    didEndEditing: { [weak self] in
                        self?.didEndEditing(index: index)
                    },
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

    func didEndEditing(index textFieldIndex: Int) {
        let phrase = provider.phrase
        guard
            let wordIndex = indexes[safe: textFieldIndex],
            let input = input[wordIndex],
            let word = phrase[safe: wordIndex]
        else {
            return
        }
        let valid = input.isEmpty || word == input
        didUpdateInputValidationState?(textFieldIndex, valid)
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
        let inputValidationStates: [Bool] = indexes.enumerated().map { _, value in
            phrase[value] == input[value]
        }
        let isValid = inputValidationStates.allSatisfy { $0 }
        for (index, value) in inputValidationStates.enumerated() {
            didUpdateInputValidationState?(index, value)
        }
        guard isValid else { return }
        didCheckRecoveryPhrase?()
    }
}

private extension Int {
    static let checkWordsCount = 3
}
