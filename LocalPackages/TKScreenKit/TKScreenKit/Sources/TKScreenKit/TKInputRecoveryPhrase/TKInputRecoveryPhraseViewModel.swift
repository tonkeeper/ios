import TKLocalize
import TKUIKit
import UIKit

public protocol TKInputRecoveryPhraseModuleOutput: AnyObject {
    var didInputRecoveryPhrase: (([String], @escaping (() -> Void)) -> Void)? { get set }
}

protocol TKInputRecoveryPhraseViewModel: AnyObject {
    var showToast: ((ToastPresenter.Configuration) -> Void)? { get set }
    var didUpdateHeaderModel: ((TKTitleDescriptionView.Model) -> Void)? { get set }
    var didUpdateInputFields: (([TKInputRecoveryPhraseView.InputFieldModel]) -> Void)? { get set }
    var didUpdateSeedPhraseSegmenteControl: ((TKInputRecoveryPhraseView.SegmentedControlModel) -> Void)? { get set }
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

    var didUpdateHeaderModel: ((TKTitleDescriptionView.Model) -> Void)?
    var didUpdateInputFields: (([TKInputRecoveryPhraseView.InputFieldModel]) -> Void)?
    var didUpdateSeedPhraseSegmenteControl: ((TKInputRecoveryPhraseView.SegmentedControlModel) -> Void)?
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
        setup()
    }

    // MARK: - State

    private enum WordsMode {
        case mode24
        case mode12

        var wordsCount: Int {
            switch self {
            case .mode24:
                return 24
            case .mode12:
                return 12
            }
        }
    }

    private var mode: WordsMode = .mode24 {
        didSet {
            didUpdateWordsMode()
        }
    }

    private var phrase: [String]
    private var activeIndex: Int?

    private var continueButtonConfiguration: TKButton.Configuration {
        didSet {
            didUpdateContinueButton?(continueButtonConfiguration)
        }
    }

    // MARK: - Configuration

    private let title: String
    private let caption: String
    private let set12WordsButtonTitle: String
    private let set24WordsButtonTitle: String
    private let continueButtonTitle: String
    private let pasteButtonTitle: String
    private let validator: TKInputRecoveryPhraseValidator
    private let suggestsProvider: TKInputRecoveryPhraseSuggestsProvider

    // MARK: - Sync queue

    private let dispatchQueue = DispatchQueue(label: "TKInputRecoveryPhraseViewModelImplementationQueue")
    private var wordValidationTasks = [Int: Task<Void, Never>]()
    private var formValidationTask: Task<Void, Never>?
    private var suggestsTasks = [Int: Task<Void, Never>]()
    private var continueValidationTask: Task<Void, Never>?
    private var updateSuggestTask: Task<Void, Never>?

    // MARK: - Init

    init(
        title: String,
        caption: String,
        set12WordsButtonTitle: String,
        set24WordsButtonTitle: String,
        continueButtonTitle: String,
        pasteButtonTitle: String,
        validator: TKInputRecoveryPhraseValidator,
        suggestsProvider: TKInputRecoveryPhraseSuggestsProvider
    ) {
        self.title = title
        self.caption = caption
        self.set12WordsButtonTitle = set12WordsButtonTitle
        self.set24WordsButtonTitle = set24WordsButtonTitle
        self.continueButtonTitle = continueButtonTitle
        self.pasteButtonTitle = pasteButtonTitle
        self.validator = validator
        self.suggestsProvider = suggestsProvider
        self.phrase = Array(repeating: "", count: mode.wordsCount)

        var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        continueButtonConfiguration.content.title = .plainString(continueButtonTitle)
        self.continueButtonConfiguration = continueButtonConfiguration
    }
}

private extension TKInputRecoveryPhraseViewModelImplementation {
    func setup() {
        setupTitleDescription()
        setupSeedPhraseModeSegmentedControl()
        setupInputFields()

        continueButtonConfiguration.action = { [weak self] in
            self?.didTapContinueButton()
        }
        var pasteButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .tertiary, size: .medium)
        pasteButtonConfiguration.content.title = .plainString(pasteButtonTitle)
        pasteButtonConfiguration.action = { [weak self] in
            guard UIPasteboard.general.hasStrings,
                  let string = UIPasteboard.general.string else { return }
            _ = self?.shouldPaste(text: string, index: 0)
        }
        didUpdatePasteButton?(pasteButtonConfiguration)
    }

    func setupTitleDescription() {
        let titleDescriptionModel = TKTitleDescriptionView.Model(
            title: title,
            bottomDescription: caption
        )
        didUpdateHeaderModel?(titleDescriptionModel)
    }

    func setupSeedPhraseModeSegmentedControl() {
        let model = TKInputRecoveryPhraseView.SegmentedControlModel(
            tabs: [set24WordsButtonTitle, set12WordsButtonTitle],
            selectedIndex: 0,
            selectionClosure: { [weak self] index in
                switch index {
                case 0:
                    self?.mode = .mode24
                case 1:
                    self?.mode = .mode12
                default:
                    break
                }
            }
        )
        didUpdateSeedPhraseSegmenteControl?(model)
    }

    func setupInputFields() {
        let inputs: [TKInputRecoveryPhraseView.InputFieldModel] = (0 ..< mode.wordsCount)
            .map { index in
                TKInputRecoveryPhraseView.InputFieldModel(
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
        didUpdateInputFields?(inputs)
    }

    func didUpdateWordsMode() {
        formValidationTask?.cancel()
        wordValidationTasks.values.forEach { $0.cancel() }
        wordValidationTasks.removeAll()
        suggestsTasks.values.forEach { $0.cancel() }
        suggestsTasks.removeAll()
        phrase = Array(repeating: "", count: mode.wordsCount)
        setupInputFields()
    }

    func didUpdateText(_ text: String, index: Int) {
        didUpdateInputValidationState?(index, true)
        phrase[index] = text
        updateSuggests(index: index)
        let isHidden = phrase.map { !$0.isEmpty }.reduce(into: false) { $0 = $0 || $1 }
        didUpdatePasteButtonIsHidden?(isHidden)
    }

    func didBeginEditing(index: Int) {
        activeIndex = index
        didSelectInput?(index)
        updateSuggests(index: index)
    }

    func didEndEditing(index: Int) {
        activeIndex = nil
        validateInput(index: index)
    }

    func validateInput(index: Int) {
        guard phrase.count > index else { return }
        let word = phrase[index]
        let task = Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let isValid = self.validator.validateWord(word) || word.isEmpty
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.didUpdateInputValidationState?(index, isValid)
            }
        }
        wordValidationTasks[index]?.cancel()
        wordValidationTasks[index] = task
    }

    func shouldPaste(text: String, index: Int) -> Bool {
        let wordsCount = mode.wordsCount
        guard index == 0 else { return false }
        let phrase = text
            .components(separatedBy: CharacterSet([" ", ",", "\n", "\u{00a0}"]))
            .filter { !$0.isEmpty }

        guard phrase.count <= wordsCount else {
            let text = "Incorrect phrase: \(phrase.count) words phrase was inserted with \(wordsCount) words mode selected."
            ToastPresenter.showToast(
                configuration: ToastPresenter.Configuration(
                    title: text
                )
            )

            return false
        }

        for (index, word) in phrase.enumerated() {
            self.phrase[index] = word
        }
        didUpdatePasteButtonIsHidden?(true)

        for (index, word) in phrase.enumerated() {
            self.didUpdateText?(index, word)
        }

        let task = Task(priority: .userInitiated) {
            let validation = phrase.map {
                self.validator.validateWord($0)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                for (index, _) in phrase.enumerated() {
                    self.didUpdateInputValidationState?(index, validation[index])
                }
                if phrase.count == wordsCount {
                    self.didPastePhrase?()
                } else {
                    self.didPaste?(phrase.count)
                }
            }
        }

        formValidationTask?.cancel()
        formValidationTask = task
        return false
    }

    func checkForApplyingSuggestion(index: Int) {
        guard let input = self.phrase[safe: index] else {
            return
        }
        let task = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let suggests = self.suggestsProvider.suggestsFor(input: input)
            guard let suggest = suggests.first else { return }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.setSuggest(suggest: suggest, index: index)
            }
        }

        suggestsTasks[index]?.cancel()
        suggestsTasks[index] = task
    }

    func didTapContinueButton() {
        continueButtonConfiguration.showsLoader = true

        formValidationTask?.cancel()
        wordValidationTasks.values.forEach { $0.cancel() }
        wordValidationTasks.removeAll()

        continueValidationTask?.cancel()
        continueValidationTask = Task(priority: .userInitiated, operation: { [weak self, phrase] in
            guard let self = self else { return }
            let validationResult = self.validator.validatePhrase(phrase)
            switch validationResult {
            case .invalid:
                let wordsValidation = phrase.map {
                    self.validator.validateWord($0)
                }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.continueButtonConfiguration.showsLoader = false
                    for (index, isValid) in wordsValidation.enumerated() {
                        self.didUpdateInputValidationState?(index, isValid)
                    }
                }
            case .multiaccount:
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.continueButtonConfiguration.showsLoader = false
                    self.showToast?(ToastPresenter.Configuration(title: TKLocales.Errors.multiaccountError))
                }
            case .ton:
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.didInputRecoveryPhrase?(phrase) {
                        self.continueButtonConfiguration.showsLoader = false
                    }
                }
            }
        })
    }

    func updateSuggests(index: Int) {
        updateSuggestTask?.cancel()
        guard phrase.count > index else { return }
        let input = phrase[index]
        updateSuggestTask = Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let suggests = self.suggestsProvider.suggestsFor(input: input)
            let model = TKInputRecoveryPhraseSuggestsView.Model(
                suggests: suggests.map { suggestText in
                    TKInputRecoveryPhraseSuggestsButton.Model(text: suggestText) { [weak self] in
                        guard let activeIndex = self?.activeIndex else { return }
                        self?.setSuggest(suggest: suggestText, index: activeIndex)
                    }
                }
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.didUpdateSuggests?(model)
            }
        }
    }

    func setSuggest(suggest: String, index: Int) {
        phrase[index] = suggest
        didUpdateText?(index, suggest)
        if index < mode.wordsCount - 1 {
            didPaste?(index + 1)
        } else {
            didPastePhrase?()
        }
    }
}
