import AppUI
import TKUIKit

final class TKCheckRecoveryPhraseViewController: TKHostingController<BackupCheckScreen>, TKOwnHeaderScreen {
    private let viewModel: TKCheckRecoveryPhraseViewModel

    private var state: BackupCheckScreenState = .empty
    private var onBack: (() -> Void)?

    init(viewModel: TKCheckRecoveryPhraseViewModel) {
        self.viewModel = viewModel
        super.init(
            content: BackupCheckScreen(
                state: .empty,
                onSelectOption: { _, _ in },
                onContinue: {}
            )
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBindings()
        viewModel.viewDidLoad()
    }

    func setupHeaderBackButton() {
        onBack = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        updateContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBar(animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreNavigationBar(animated: animated)
    }
}

private extension TKCheckRecoveryPhraseViewController {
    func setupBindings() {
        viewModel.didUpdateState = { [weak self] state in
            self?.state = state
            self?.updateContent()
        }
    }

    func updateContent() {
        content = BackupCheckScreen(
            state: state,
            onBack: onBack,
            onSelectOption: { [weak viewModel] wordIndex, word in
                viewModel?.didSelect(wordIndex: wordIndex, word: word)
            },
            onContinue: { [weak viewModel] in
                viewModel?.didTapContinueButton()
            }
        )
    }
}

private extension BackupCheckScreenState {
    static let empty = BackupCheckScreenState(
        title: "",
        caption: "",
        buttonTitle: "",
        rows: [],
        isContinueEnabled: false,
        isError: false,
        failedAttemptCount: 0
    )
}
