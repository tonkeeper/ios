import AppUI

protocol TKCheckRecoveryPhraseModuleOutput: AnyObject {
    var didCheckRecoveryPhrase: (() -> Void)? { get set }
    var didFailCheckRecoveryPhrase: (() -> Void)? { get set }
}

protocol TKCheckRecoveryPhraseViewModel: AnyObject {
    var didUpdateState: ((BackupCheckScreenState) -> Void)? { get set }

    func viewDidLoad()
    func didSelect(wordIndex: Int, word: String)
    func didTapContinueButton()
}

protocol TKCheckRecoveryPhraseProvider {
    var title: String { get }
    func caption(numberOne: Int, numberTwo: Int, numberThree: Int) -> String
    var buttonTitle: String { get }
    var phrase: [String] { get }
    var validWords: [String] { get }
    var errorCaption: String { get }
}

final class TKCheckRecoveryPhraseViewModelImplementation: TKCheckRecoveryPhraseViewModel, TKCheckRecoveryPhraseModuleOutput {
    var didCheckRecoveryPhrase: (() -> Void)?
    var didFailCheckRecoveryPhrase: (() -> Void)?
    var didUpdateState: ((BackupCheckScreenState) -> Void)?

    private let provider: TKCheckRecoveryPhraseProvider
    private let indexes: [Int]
    private let options: [Int: [String]]

    private var selected = [Int: String]()
    private var isError = false
    private var failedAttemptCount = 0

    init(provider: TKCheckRecoveryPhraseProvider) {
        self.provider = provider

        let phrase = provider.phrase
        indexes = Array(0 ..< phrase.count)
            .shuffled()
            .prefix(3)
            .sorted()

        let distractorPool = provider.validWords.filter { !phrase.contains($0) }
        var options = [Int: [String]]()
        for wordIndex in indexes {
            let distractors = Array(distractorPool.shuffled().prefix(2))
            options[wordIndex] = ([phrase[wordIndex]] + distractors).shuffled()
        }
        self.options = options
    }

    func viewDidLoad() {
        updateState()
    }

    func didSelect(wordIndex: Int, word: String) {
        selected[wordIndex] = word
        isError = false
        updateState()
    }

    func didTapContinueButton() {
        let phrase = provider.phrase
        let isValid = indexes.allSatisfy { phrase[$0] == selected[$0] }
        guard isValid else {
            isError = true
            failedAttemptCount += 1
            updateState()
            didFailCheckRecoveryPhrase?()
            return
        }
        didCheckRecoveryPhrase?()
    }
}

private extension TKCheckRecoveryPhraseViewModelImplementation {
    func updateState() {
        let caption: String
        if isError {
            caption = provider.errorCaption
        } else {
            caption = provider.caption(
                numberOne: indexes[0] + 1,
                numberTwo: indexes[1] + 1,
                numberThree: indexes[2] + 1
            )
        }

        didUpdateState?(
            BackupCheckScreenState(
                title: provider.title,
                caption: caption,
                buttonTitle: provider.buttonTitle,
                rows: indexes.map { wordIndex in
                    BackupCheckScreenState.Row(
                        id: wordIndex,
                        number: wordIndex + 1,
                        options: options[wordIndex] ?? [],
                        selectedOption: selected[wordIndex]
                    )
                },
                isContinueEnabled: selected.count == indexes.count,
                isError: isError,
                failedAttemptCount: failedAttemptCount
            )
        )
    }
}
